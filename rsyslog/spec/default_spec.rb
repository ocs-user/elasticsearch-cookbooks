require 'spec_helper'

describe 'rsyslog::default' do
  let(:chef_run) do
    ChefSpec::ChefRunner.new(platform: 'ubuntu', version: '12.04').converge('rsyslog::default')
  end

  let(:service_resource) { 'service[rsyslog]' }

  it 'installs the rsyslog part' do
    expect(chef_run).to install_package('rsyslog')
  end

  context "when node['rsyslog']['relp'] is true" do
    let(:chef_run) do
      ChefSpec::ChefRunner.new(platform: 'ubuntu', version: '12.04') do |node|
        node.set['rsyslog']['use_relp'] = true
      end.converge('rsyslog::default')
    end

    it 'installs the rsyslog-relp package' do
      expect(chef_run).to install_package('rsyslog-relp')
    end
  end

  context "when node['rsyslog']['enable_tls'] is true" do
    context "when node['rsyslog']['tls_ca_file'] is not set" do
      let(:chef_run) do
        ChefSpec::ChefRunner.new(platform: 'ubuntu', version: '12.04') do |node|
          node.set['rsyslog']['enable_tls'] = true
        end.converge('rsyslog::default')
      end

      it 'does not install the rsyslog-gnutls package' do
        expect(chef_run).not_to install_package('rsyslog-gnutls')
      end
    end

    context "when node['rsyslog']['tls_ca_file'] is set" do
      let(:chef_run) do
        ChefSpec::ChefRunner.new(platform: 'ubuntu', version: '12.04') do |node|
          node.set['rsyslog']['enable_tls'] = true
          node.set['rsyslog']['tls_ca_file'] = '/etc/path/to/ssl-ca.crt'
        end.converge('rsyslog::default')
      end

      it 'installs the rsyslog-gnutls package' do
        expect(chef_run).to install_package('rsyslog-gnutls')
      end

      context "when protocol is not 'tcp'" do
        before do
          Chef::Log.stub(:fatal)
          $stdout.stub(:puts)
        end

        let(:chef_run) do
          ChefSpec::ChefRunner.new(platform: 'ubuntu', version: '12.04') do |node|
            node.set['rsyslog']['enable_tls'] = true
            node.set['rsyslog']['tls_ca_file'] = '/etc/path/to/ssl-ca.crt'
            node.set['rsyslog']['protocol'] = 'udp'
          end.converge('rsyslog::default')
        end

        it 'exits fatally' do
          expect{ chef_run }.to raise_error(SystemExit)
        end
      end
    end

  end

  context '/etc/rsyslog.d directory' do
    let(:directory) { chef_run.directory('/etc/rsyslog.d') }

    it 'creates the directory' do
      expect(chef_run).to create_directory(directory.path)
    end

    it 'is owned by root:root' do
      expect(directory.owner).to eq('root')
      expect(directory.group).to eq('root')
    end

    it 'has 0755 permissions' do
      expect(directory.mode).to eq('0755')
    end

    context 'on SmartOS' do
      let(:chef_run) do
        ChefSpec::ChefRunner.new(platform: 'smartos', version: 'joyent_20130111T180733Z').converge('rsyslog::default')
      end

      let(:directory) { chef_run.directory('/opt/local/etc/rsyslog.d') }

      it 'creates the directory' do
        expect(chef_run).to create_directory(directory.path)
      end

      it 'is owned by root:root' do
        expect(directory.owner).to eq('root')
        expect(directory.group).to eq('root')
      end

      it 'has 0755 permissions' do
        expect(directory.mode).to eq('0755')
      end
    end
  end

  context '/var/spool/rsyslog directory' do
    let(:directory) { chef_run.directory('/var/spool/rsyslog') }

    it 'creates the directory' do
      expect(chef_run).to create_directory('/var/spool/rsyslog')
    end

    it 'is owned by root:root' do
      expect(directory.owner).to eq('root')
      expect(directory.group).to eq('root')
    end

    it 'has 0755 permissions' do
      expect(directory.mode).to eq('0755')
    end
  end

  context '/etc/rsyslog.conf template' do
    let(:template) { chef_run.template('/etc/rsyslog.conf') }
    let(:modules) { %w(imuxsock imklog) }

    it 'creates the template' do
      expect(chef_run).to create_file_with_content(template.path, 'Configuration file for rsyslog v3')
    end

    it 'is owned by root:root' do
      expect(template.owner).to eq('root')
      expect(template.group).to eq('root')
    end

    it 'has 0644 permissions' do
      expect(template.mode).to eq('0644')
    end

    it 'notifies restarting the service' do
      expect(template).to notify(service_resource, :restart)
    end

    it 'includes the right modules' do
      modules.each do |mod|
        expect(chef_run).to create_file_with_content(template.path, /^\$ModLoad #{mod}/)
      end
    end

    context 'on SmartOS' do
      let(:chef_run) do
        ChefSpec::ChefRunner.new(platform: 'smartos', version: 'joyent_20130111T180733Z').converge('rsyslog::default')
      end

      let(:template) { chef_run.template('/opt/local/etc/rsyslog.conf') }
      let(:modules) { %w(immark imsolaris imtcp imudp) }

      it 'creates the template' do
        expect(chef_run).to create_file_with_content(template.path, 'Configuration file for rsyslog v3')
      end

      it 'is owned by root:root' do
        expect(template.owner).to eq('root')
        expect(template.group).to eq('root')
      end

      it 'has 0644 permissions' do
        expect(template.mode).to eq('0644')
      end

      it 'notifies restarting the service' do
        expect(template).to notify(service_resource, :restart)
      end

      it 'includes the right modules' do
        modules.each do |mod|
          expect(chef_run).to create_file_with_content(template.path, /^\$ModLoad #{mod}/)
        end
      end
    end
  end

  context '/etc/rsyslog.d/50-default.conf template' do
    let(:template) { chef_run.template('/etc/rsyslog.d/50-default.conf') }

    it 'creates the template' do
      expect(chef_run).to create_file_with_content('/etc/rsyslog.d/50-default.conf', '*.emerg    *')
    end

    it 'is owned by root:root' do
      expect(template.owner).to eq('root')
      expect(template.group).to eq('root')
    end

    it 'has 0644 permissions' do
      expect(template.mode).to eq('0644')
    end

    it 'notifies restarting the service' do
      expect(template).to notify(service_resource, :restart)
    end

    context 'on SmartOS' do
      let(:chef_run) do
        ChefSpec::ChefRunner.new(platform: 'smartos', version: 'joyent_20130111T180733Z').converge('rsyslog::default')
      end

      let(:template) { chef_run.template('/opt/local/etc/rsyslog.d/50-default.conf') }

      it 'creates the template' do
        expect(chef_run).to create_file_with_content(template.path, 'Default rules for rsyslog.')
      end

      it 'is owned by root:root' do
        expect(template.owner).to eq('root')
        expect(template.group).to eq('root')
      end

      it 'has 0644 permissions' do
        expect(template.mode).to eq('0644')
      end

      it 'notifies restarting the service' do
        expect(template).to notify(service_resource, :restart)
      end

      it 'uses the SmartOS-specific template' do
        expect(chef_run).to create_file_with_content(template.path, %r{/var/adm/messages$})
      end
    end
  end

  context 'COOK-3608 maillog regression test' do
    let(:chef_run) do
      ChefSpec::ChefRunner.new(platform: 'redhat', version: '6.3').converge('rsyslog::default')
    end

    it 'outputs mail.* to /var/log/maillog' do
      expect(chef_run).to create_file_with_content('/etc/rsyslog.d/50-default.conf', 'mail.*    -/var/log/maillog')
    end
  end

  context 'syslog service' do
    let(:chef_run) do
      ChefSpec::ChefRunner.new(platform: 'redhat', version: '5.8').converge('rsyslog::default')
    end

    it 'stops and starts the syslog service on RHEL' do
      expect(chef_run).to stop_service('syslog')
      expect(chef_run).to disable_service('syslog')
    end
  end

  context 'system-log service' do
    { 'omnios' => '151002', 'smartos' => 'joyent_20130111T180733Z' }.each do |p, pv|
      let(:chef_run) do
        ChefSpec::ChefRunner.new(platform: p, version: pv).converge('rsyslog::default')
      end

      it "stops the system-log service on #{p}" do
        expect(chef_run).to disable_service('system-log')
      end
    end
  end

  context 'on OmniOS' do
    let(:chef_run) do
      ChefSpec::ChefRunner.new(platform: 'omnios', version: '151002').converge('rsyslog::default')
    end

    let(:template) { chef_run.template('/var/svc/manifest/system/rsyslogd.xml') }
    let(:execute) { chef_run.execute('import rsyslog manifest') }

    it 'creates the custom SMF manifest' do
      expect(chef_run).to create_file(template.path)
    end

    it 'notifies svccfg to import the manifest' do
      expect(template).to notify('execute[import rsyslog manifest]', :run)
    end

    it 'notifies rsyslog to restart when importing the manifest' do
      expect(execute).to notify('service[system/rsyslogd]', :restart)
    end
  end

  context 'rsyslog service' do
    it 'starts and enables the service' do
      expect(chef_run).to set_service_to_start_on_boot('rsyslog')
    end
  end
end
