module Bosh
  module GCECloud; end
end

require "bosh/registry/client"

Dir['cloud/gce/*.rb'].each { |d| require d }
