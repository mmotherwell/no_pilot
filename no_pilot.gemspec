# frozen_string_literal: true

require_relative "lib/no_pilot/version"

Gem::Specification.new do |spec|
  spec.name = "no_pilot"
  spec.version = NoPilot::VERSION
  spec.authors = ["Michael Motherwell"]
  spec.email = ["mmotherwell@gmail.com"]

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.summary = "Generate controller tests automatically for every route"
  spec.description = "System specs are flaky and unreliable, prone to timing issues. Request specs are less flakey, faster, but less comprehsensive."
  spec.homepage = "http://michaelmotherwell.com"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mmotherwell/no_pilot"
  spec.metadata["changelog_uri"] = "https://github.com/mmotherwell/no_pilot/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.bindir = "bin"
  spec.executables = "no_pilot"
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.2"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "standardrb"
  spec.add_development_dependency "chusaku"

  spec.add_dependency "railties", ">= 3.0"
end
