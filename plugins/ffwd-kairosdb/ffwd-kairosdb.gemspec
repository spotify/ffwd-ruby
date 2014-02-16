# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ffwd/plugin/kairosdb/version'

Gem::Specification.new do |spec|
  spec.name = "ffwd-kairosdb"
  spec.version = FFWD::Plugin::KairosDB::VERSION
  spec.authors = ["John-John Tedro"]
  spec.email = ["udoprog@spotify.com"]
  spec.summary = %q{KairosDB support for FFWD.}
  spec.homepage = "https://github.com/spotify-ffwd/ffwd-kairosdb"
  spec.license = "Apache 2.0"

  spec.files = Dir.glob('lib/**/*.rb');

  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})

  spec.require_paths = ["lib"]

  spec.add_dependency "em-http-request"

  spec.add_development_dependency "ffwd"
end
