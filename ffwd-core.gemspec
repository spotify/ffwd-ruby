# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ffwd/version'

Gem::Specification.new do |spec|
  spec.name = "ffwd-core"
  spec.version = FFWD::VERSION
  spec.authors = ["John-John Tedro"]
  spec.email = ["johnjohn.tedro@gmail.com"]
  spec.description = %q{Minimal System Event Daemon}
  spec.summary = %q{Minimal System Event Daemon}
  spec.homepage = "https://github.com/spotify/ffwd-core"
  spec.license = "GPLv3"

  spec.files = Dir.glob('bin/*') +
               Dir.glob('lib/**/*.rb');

  spec.executables = ['ffwd', 'fwc']
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})

  spec.require_paths = ["lib"]

  spec.add_dependency "eventmachine"

  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-mocks"
end
