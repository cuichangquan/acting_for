ENV["RAILS_ENV"] ||= "test"

require_relative "dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = Rails.application.paths["db/migrate"].to_a
require "rails/test_help"
