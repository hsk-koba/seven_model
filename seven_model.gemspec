# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "seven_model/version"

Gem::Specification.new do |spec|
  spec.name          = "seven_model"
  spec.version       = SevenModel::VERSION
  spec.authors       = ["Masaki Hara", "Masayuki Izumi", "Wantedly, Inc.", "Itsuki Kobashigawa"]
  spec.email         = ["ackie.h.gmai@gmail.com", "m@izum.in", "dev@wantedly.com", "itsuki-k@nxvem.jp"]

  spec.summary       = %q{Batch loader with dependency resolution and computed fields}
  spec.description   = <<~DSC
    SevenModel (renamed from ComputedModel) is a helper for building a read-only model
    from multiple sources of models. It targets Rails 7+ and comes with batch loading
    and dependency resolution for better performance.
  DSC
  spec.homepage      = "https://github.com/wantedly/computed_model"
  spec.licenses      = ["MIT"]

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/wantedly/computed_model"
  spec.metadata["changelog_uri"] = "https://github.com/wantedly/computed_model/blob/master/CHANGELOG.md"

  spec.files         = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "activesupport", ">= 7.2", "< 9"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "activerecord", ">= 7.2", "< 9"
  spec.add_development_dependency "sqlite3", ">= 1.6.6", "< 3"
  spec.add_development_dependency "factory_bot", "~> 6.1"
  spec.add_development_dependency "simplecov", "~> 0.21.2"
  spec.add_development_dependency "simplecov-lcov", "~> 0.8.0"
end
