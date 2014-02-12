# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ffwd/plugin/tunnel/version'

Gem::Specification.new do |spec|
  spec.name = "ffwd-tunnel"
  spec.version = FFWD::Plugin::Tunnel::VERSION
  spec.authors = ["John-John Tedro"]
  spec.email = ["udoprog@spotify.com"]
  spec.summary = %q{Simple tunneling support for FFWD.}
  spec.homepage = "https://github.com/spotify-ffwd/ffwd-tunnel"
  spec.license = "Apache 2.0"

  spec.files = Dir.glob('bin/*') +
               Dir.glob('lib/**/*.rb');

  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})

  spec.executables = ["ffwd-tunnel-agent"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "ffwd-core"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-mocks"
end
