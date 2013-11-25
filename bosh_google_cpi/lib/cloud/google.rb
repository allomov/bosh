module Bosh
  module Google
  end
end

require "bosh/registry/client"

Dir['cloud/gce/*.rb'].each { |d| require d }
