
# TODO: remove after fog is updated 
require 'mime/types'

module Bosh
  module Google
  end
end

require "bosh/registry/client"

require "common/exec"
require "common/thread_pool"
require "common/thread_formatter"

require "fog"
require "google/api_client"

require "cloud"
require "cloud/google/common_helpers"
require "cloud/google/helpers"
require "cloud/google/constants"

require "cloud/google/cloud"


Dir['cloud/google/**/*.rb'].each { |d| require d }

module Bosh
  module Clouds
    Google = Bosh::Google::Cloud
  end
end
