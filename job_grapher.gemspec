# frozen_string_literal: true

require_relative "lib/job_grapher/version"

Gem::Specification.new do |spec|
  spec.name = "job_grapher"
  spec.version = JobGrapher::VERSION
  spec.authors = ["Jeremy Friesen"]
  spec.email = ["jeremy.n.friesen@gmail.com"]

  spec.summary = "A naive graph generator for ActiveJob's declared and called across projects."
  spec.description = "A naive graph generator for ActiveJob's declared and called across projects."
  spec.homepage = "https://github.com/jeremyf/job_grapher"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] =  spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
