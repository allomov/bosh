module Bosh
  module Google
  end
end

require "bosh/registry/client"

Dir['cloud/google/**/*.rb'].each { |d| require d }
