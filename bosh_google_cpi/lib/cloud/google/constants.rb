module Bosh::Google

  module Constants

    def self.default_max_retries
      2
    end

    def image_root_file
      'disk.raw'
    end

  end

end