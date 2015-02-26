# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ffwd/version'

Gem::Specification.new do |spec|
  spec.name = "ffwd"
  spec.version = FFWD::VERSION
  spec.authors = ["John-John Tedro", "Martin Parm"]
  spec.email = ["udoprog@spotify.com", "parmus@spotify.com"]
  spec.summary = %q{Core framework for the FastForward Daemon.}
  spec.homepage = "https://github.com/spotify/ffwd"
  spec.license = "Apache 2.0"

  spec.files = Dir.glob('bin/*') +
               Dir.glob('lib/**/*.rb');

  spec.executables = ['ffwd', 'fwc']
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})

  spec.require_paths = ["lib"]

  spec.add_dependency "eventmachine", "1.0.4"

  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-mocks"
  spec.add_development_dependency "autoversion"
end
