require 'pp'
require 'bosh/deployer'
require 'bosh/deployer/deployer_renderer'
require 'bosh/stemcell'
require 'bosh/stemcell/archive'

module Bosh::Cli::Command
  class MultiCloud < Base

    def initialize(runner)
      super(runner)
      options[:config] ||= DEFAULT_CONFIG_PATH # hijack Cli::Config
    end

    usage 'clouds'
    desc 'show list of available clouds'
    def list
      list = director.list_clouds
      
      err('No Clouds Available.'.make_red) if list.empty?
      
      say('Available Clouds:')
      nl

      deployments_table = table do |t|
        t.headings = ['Name', 'Type', 'Endpoint']
        deployments.each do |d|
          t.add_row(row_for_deployments_table(d))
          t.add_separator unless d == deployments.last
        end
      end
    end

    usage 'add cloud'
    desc 'adds new cloud'
    def create(config_path)
      auth_required

      config_yaml = read_yaml_file(config_path)

      if director.create_cloud(config_yaml)
        say("Successfully updated cloud config")
      else
        err("Failed to update cloud config")
      end
      
    end

    usage 'delete cloud'
    desc 'delete cloud'
    def delete(name = nil)
      
    end


  end
end
