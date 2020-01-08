# frozen_string_literal: true

test_name "Install Ruby" do
  step "Ensure Ruby is installed on Bolt controller" do
    result = nil
    case bolt['platform']
    when /windows/
      # use chocolatey to install latest ruby
      execute_powershell_script_on(bolt, <<-PS)
Set-ExecutionPolicy AllSigned
$choco_install_uri = 'https://chocolatey.org/install.ps1'
iex ((New-Object System.Net.WebClient).DownloadString($choco_install_uri))
PS
      # HACK: to add chocolatey path to cygwin: this path should at least be
      # instrospected from the STDOUT of the installer.
      bolt.add_env_var('PATH', '/cygdrive/c/ProgramData/chocolatey/bin:PATH')
      on(bolt, powershell('choco install ruby -y --version 2.5.3.101'))
      on(bolt, powershell('choco list --lo ruby')) do |output|
        version = /ruby (2\.[0-9])/.match(output.stdout)[1].delete('.')
        bolt.add_env_var('PATH', "/cygdrive/c/tools/ruby#{version}/bin:PATH")
      end
      result = on(bolt, powershell('ruby --version'))
    when /debian|ubuntu/
      # install system ruby packages
      install_package(bolt, 'ruby')
      install_package(bolt, 'ruby-ffi')
      result = on(bolt, 'ruby --version')
    when /el-|centos/
      # install system ruby packages
      install_package(bolt, 'ruby')
      install_package(bolt, 'rubygem-json')
      install_package(bolt, 'rubygem-ffi')
      install_package(bolt, 'rubygem-bigdecimal')
      install_package(bolt, 'rubygem-io-console')
      result = on(bolt, 'ruby --version')
    when /fedora/
      # install system ruby packages
      install_package(bolt, 'ruby')
      install_package(bolt, 'ruby-devel')
      install_package(bolt, 'libffi')
      install_package(bolt, 'libffi-devel')
      install_package(bolt, 'redhat-rpm-config')
      on(bolt, "dnf group install -y 'C Development Tools and Libraries'")
      install_package(bolt, 'rubygem-json')
      install_package(bolt, 'rubygem-bigdecimal')
      install_package(bolt, 'rubygem-io-console')
      result = on(bolt, 'ruby --version')
    when /osx/
      # System ruby for osx is 2.3. winrm-fs > 1.3.3 and gettext >= 3.3.0
      # require Ruby > 2.3, so explicitly install compatible versions first.
      on(bolt, 'gem install gettext -v 3.2.9 --no-rdoc --no-ri')
      on(bolt, 'gem install winrm-fs -v 1.3.3 --no-rdoc --no-ri')
      result = on(bolt, 'ruby --version')
    else
      fail_test("#{bolt['platform']} not currently a supported bolt controller")
    end
    assert_match(/ruby 2/, result.stdout)
  end
end
