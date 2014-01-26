require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

BASE_URL = "git@github.com"

PLUGINS = [
  :collectd,
  :kafka,
  :kairosdb,
  :riemann,
  :statsd,
  :tunnel,
  :carbon,
]

task :dev do
  mkdir "plugins"
  PLUGINS.each do |plugin|
    clone_url = "#{BASE_URL}:spotify-ffwd/ffwd-#{plugin}"
    target_dir = "./plugins/ffwd-#{plugin}"
    system "git clone #{clone_url} #{target_dir}"
  end
end
