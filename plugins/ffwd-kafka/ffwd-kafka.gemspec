# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ffwd/plugin/kafka/version'

Gem::Specification.new do |spec|
  spec.name = "ffwd-kafka"
  spec.version = FFWD::Plugin::Kafka::VERSION
  spec.authors = ["John-John Tedro"]
  spec.email = ["udoprog@spotify.com"]
  spec.summary = %q{Kafka support for FFWD.}
  spec.homepage = "https://github.com/spotify-ffwd/ffwd-kafka"
  spec.license = "Apache 2.0"

  spec.files = Dir.glob('lib/**/*.rb');

  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})

  spec.require_paths = ["lib"]

  spec.add_dependency "zookeeper"
  spec.add_dependency "poseidon"

  spec.add_development_dependency "ffwd-core"
end
