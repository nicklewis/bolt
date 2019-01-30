#! /opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'puppet'
require 'puppet/configurer'
require 'puppet/module_tool/tar'
require 'securerandom'
require 'tempfile'

args = JSON.parse(ARGV[0] ? File.read(ARGV[0]) : STDIN.read)

# Create temporary directories for all core Puppet settings so we don't clobber
# existing state or read from puppet.conf. Also create a temporary modulepath.
# Additionally include rundir, which gets its own initialization.
puppet_root = Dir.mktmpdir
moduledir = File.join(puppet_root, 'modules')
Dir.mkdir(moduledir)
cli = (Puppet::Settings::REQUIRED_APP_SETTINGS + [:rundir]).flat_map do |setting|
  ["--#{setting}", File.join(puppet_root, setting.to_s.chomp('dir'))]
end
cli << '--modulepath' << moduledir
Puppet.initialize_settings(cli)

exit_code = 0
begin
  # This happens implicitly when running the Configurer, but we make it explicit here. It creates the
  # directories we configured earlier.
  Puppet.settings.use(:main)

  Tempfile.open('plugins.tar.gz') do |plugins|
    File.binwrite(plugins, Base64.decode64(args['plugins']))
    Puppet::ModuleTool::Tar.instance.unpack(plugins, moduledir, Etc.getlogin || Etc.getpwuid.name)
  end

  env = Puppet.lookup(:environments).get('production')
  # Needed to ensure features are loaded
  env.each_plugin_directory do |dir|
    $LOAD_PATH << dir unless $LOAD_PATH.include?(dir)
  end
  excluded_types = %i[stage component schedule filebucket]

  Puppet.override(current_environment: env,
                  loaders: Puppet::Pops::Loaders.new(env)) do
    catalog = Puppet::Resource::Catalog.from_data_hash(args['catalog'])
    catalog = catalog.to_ral
    catalog.finalize

    results = {
      "resource" => {}
    }
    catalog.resources.reject { |res| excluded_types.include?(res.type) }.each do |resource|
      resource_hash = resource.parameters.inject({}) do |acc, (name, param)|
        next acc if param.metaparam? || name == :internal_puppet_namevar
        acc.merge(name => param.value)
      end

      if resource.type == :output
        results['output'] ||= {}
        results['output'][resource.title] = resource_hash
      elsif resource.type.to_s.start_with?('provider_')
        resource_hash['alias'] = resource.title
        results['provider'] ||= []
        provider_type = resource.type.to_s.split('_', 2)[1]
        results['provider'] << {
          provider_type => resource_hash
        }
      else
        results['resource'][resource.type] ||= {}
        results['resource'][resource.type][resource.title] = resource_hash
      end
    end

    FileUtils.mkdir_p('/tmp/tf')
    File.write('/tmp/tf/catalog.tf', JSON.pretty_generate(results))
  end

  Dir.chdir('/tmp/tf') do
    `terraform init && terraform apply -auto-approve`

    exit_code = $?.to_i

    outputs = JSON.parse(`terraform output -json`).inject({}) do |acc, (param, hash)|
      acc.merge(param => hash['value'])
    end

    puts({outputs: outputs}.to_json)
  end
ensure
  begin
    FileUtils.remove_dir(puppet_root)
  rescue Errno::ENOTEMPTY => e
    STDERR.puts("Could not cleanup temporary directory: #{e}")
  end
end

exit exit_code
