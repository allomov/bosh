require 'pp'
require 'bosh/deployer'
require 'bosh/deployer/deployer_renderer'
require 'bosh/stemcell'
require 'bosh/stemcell/archive'

module Bosh::Cli::Command
  class MultiCloud < Base

    def initialize(runner)
      super(runner)
    end

    usage 'clouds'
    desc 'show list of available clouds'
    def list
      clouds = director.list_clouds
      
      err('No Clouds Available.'.make_red) if clouds.empty?

      nl
      say('Available Clouds:')
      

      clouds_table = table do |t|
        t.headings = ['Name', 'Type', 'Endpoint']
        clouds.each do |c|
          t.add_row([c.name.make_green, c.type, c.endpoint])
          t.add_separator unless c == clouds.last
        end
      end
      nl
      say(clouds_table)
      nl
    end

    usage 'add cloud'
    desc 'adds new cloud'
    def create(config_path)
      auth_required

      config_yaml = read_yaml_file(config_path)

      if director.create_cloud(config_yaml)
        say("Successfully add the cloud.".make_green)
      else
        err("Failed to update cloud config".make_red)
      end
      
    end

    usage 'delete cloud'
    desc 'delete cloud'
    def delete(name)
      auth_required
      director.delete_cloud(name)
    end


  end
end
