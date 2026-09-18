require_relative "boot"

require "rails"
require "active_record/railtie"
require "acting_for"

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.0
  end
end
