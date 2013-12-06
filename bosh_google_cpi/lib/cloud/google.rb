module Bosh
  module Google
  end
end

require "bosh/registry/client"

require "cloud/google/common_helpers"
require "cloud/google/helpers"
require "cloud/google/constants"

require "cloud/google/cloud"

Dir['cloud/google/**/*.rb'].each { |d| require d }
