# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'tmpdir'
require 'bolt/transport/base'
require 'bolt/transport/powershell'
require 'bolt/util'

module Bolt
  module Transport
    class Buildah < Local
      def provided_features
        ['shell']
      end

      def self.validate(_options); end

      def initialize
        super
        @conn = Shell.new
      end

      def in_tmpdir(target)
        begin
          dir = buildah_execute(target, 'mktemp -d').stdout.read.chomp
          yield dir
        ensure
          buildah_execute(target, ['rm', '-rf', dir])
        end
      rescue StandardError => e
        raise Bolt::Node::FileError.new("Could not make tempdir: #{e.message}", 'TEMPDIR_ERROR')
      end
      private :in_tmpdir

      def copy_file(target, source, destination)
        @conn.execute('buildah', 'copy', target.host, source, destination, dir: '.')
      rescue StandardError => e
        raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
      end

      def chmod(target, mode, file)
        buildah_execute(target, ['chmod', mode.to_s(8), file])
      end

      def mkdir_p(target, files)
        buildah_execute(target, ['mkdir', '-p', *files])
      end

      def with_tmpscript(target, script, base)
        in_tmpdir(target) do |dir|
          dest = File.join(dir, File.basename(script))
          copy_file(target, script, dest)
          chmod(target, 0o750, dest)
          yield dest, dir
        end
      end
      private :with_tmpscript

      def upload(target, source, destination, _options = {})
        copy_file(target, source, destination)
        Bolt::Result.for_upload(target, source, destination)
      end

      # Run a command inside the image
      def buildah_execute(target, command, **options)
        command_str = command.is_a?(String) ? command : Shellwords.shelljoin(command)
        if options.key?(:environment)
          env_decls = options[:environment].map do |env, val|
            "#{env}=#{Shellwords.shellescape(val)}"
          end
          command_str = "#{env_decls.join(' ')} #{command_str}"
        end
        @conn.execute('buildah', 'run', target.host, 'sh', '-c', command_str, **options.merge(dir: '.'))
      end

      def run_command(target, command, _options = {})
        in_tmpdir(target) do |dir|
          output = buildah_execute(target, command, dir: dir)
          Bolt::Result.for_command(target, output.stdout.string, output.stderr.string, output.exit_code)
        end
      end

      def run_script(target, script, arguments, _options = {})
        with_tmpscript(target, File.absolute_path(script)) do |file, dir|
          logger.debug "Running '#{file}' with #{arguments}"

          # unpack any Sensitive data AFTER we log
          arguments = unwrap_sensitive_args(arguments)
          if arguments.empty?
            # We will always provide separated arguments, so work-around Open3's handling of a single
            # argument as the entire command string for script paths containing spaces.
            arguments = ['']
          end
          output = buildah_execute(target, file, *arguments, dir: dir)
          Bolt::Result.for_command(target, output.stdout.string, output.stderr.string, output.exit_code)
        end
      end

      def run_task(target, task, arguments, _options = {})
        implementation = select_implementation(target, task)
        executable = implementation['path']
        input_method = implementation['input_method']
        extra_files = implementation['files']

        in_tmpdir(target) do |dir|
          if extra_files.empty?
            script = File.join(dir, File.basename(executable))
          else
            arguments['_installdir'] = dir
            script_dest = File.join(dir, task.tasks_dir)
            mkdir_p(target, [script_dest] + extra_files.map { |file| File.join(dir, File.dirname(file['name'])) })

            script = File.join(script_dest, File.basename(executable))
            extra_files.each do |file|
              dest = File.join(dir, file['name'])
              copy_file(target, file['path'], dest)
              chmod(target, 0o750, dest)
            end
          end

          copy_file(target, executable, script)
          chmod(target, 0o750, script)

          # log the arguments with sensitive data redacted, do NOT log unwrapped_arguments
          logger.debug("Running '#{script}' with #{arguments}")
          unwrapped_arguments = unwrap_sensitive_args(arguments)

          stdin = STDIN_METHODS.include?(input_method) ? JSON.dump(unwrapped_arguments) : nil

          env = ENVIRONMENT_METHODS.include?(input_method) ? envify_params(unwrapped_arguments) : nil
          output = buildah_execute(target, script, stdin: stdin, environment: env, dir: dir)

          Bolt::Result.for_task(target, output.stdout.string, output.stderr.string, output.exit_code)
        end
      end

      def connected?(_targets)
        true
      end
    end
  end
end

require 'bolt/transport/local/shell'

