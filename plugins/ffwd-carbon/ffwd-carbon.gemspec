# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ffwd/plugin/carbon/version'

Gem::Specification.new do |spec|
  spec.name = "ffwd-carbon"
  spec.version = FFWD::Plugin::Carbon::VERSION
  spec.authors = ["Martin Parm"]
  spec.email = ["parmus@spotify.com"]
  spec.summary = %q{Carbon support for FFWD.}
  spec.homepage = "https://github.com/spotify-ffwd/ffwd-carbon"
  spec.license = "Apache 2.0"

  spec.files = Dir.glob('lib/**/*.rb');

  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})

  spec.require_paths = ["lib"]

  spec.add_development_dependency "ffwd-core"
end
