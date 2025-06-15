no_pilot_lib = File.expand_path(File.dirname(__FILE__, 2))

desc "Add request specs to your Rails specifications"
task no_pilot: :environment do
  require "#{no_pilot_lib}/no_pilot/cli"

  NoPilot::CLI.new.call(ARGV[2...] || [])
end
