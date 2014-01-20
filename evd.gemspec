# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'evd/version'

Gem::Specification.new do |spec|
  spec.name = "evd"
  spec.version = EVD::VERSION
  spec.authors = ["John-John Tedro"]
  spec.email = ["johnjohn.tedro@gmail.com"]
  spec.description = %q{Minimal System Event Daemon}
  spec.summary = %q{Minimal System Event Daemon}
  spec.homepage = ""
  spec.license = "GPLv3"

  spec.files = Dir.glob('bin/*') +
               Dir.glob('lib/**/*.rb');

  spec.executables = ['evd', 'evc']
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})

  spec.require_paths = ["lib"]

  spec.add_dependency "eventmachine"
  spec.add_dependency "riemann-client"

  spec.add_dependency "zookeeper"
  spec.add_dependency "poseidon"
  spec.add_dependency "em-http-request"

  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-mocks"
end
