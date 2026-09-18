require_relative "lib/acting_for/version"

Gem::Specification.new do |spec|
  spec.name = "acting_for"
  spec.version = ActingFor::VERSION
  spec.authors = ["ChangQuan Cui"]
  spec.summary = "Rails-native delegated authorization for AI agents."
  spec.homepage = "https://github.com/cuichangquan/acting_for"
  spec.license = "MIT"
  spec.required_ruby_version = [">= 3.4", "< 4.1"]

  spec.metadata = {
    "source_code_uri" => "https://github.com/cuichangquan/acting_for"
  }

  spec.files = Dir["lib/**/*", "app/**/*", "db/**/*", "README.md", "LICENSE*"].select { |file| File.file?(file) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 8.0", "< 8.2"
  spec.add_dependency "activesupport", ">= 8.0", "< 8.2"
  spec.add_dependency "railties", ">= 8.0", "< 8.2"
end
