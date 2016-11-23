#!/usr/bin/env ruby

require 'sys-filesystem'
require 'pagerduty'
require 'optparse'
require 'ostruct'

STDOUT.sync = true
options = OpenStruct.new()
options[:hostname] = ENV['HOSTNAME']
options[:period] = 60
options[:volumes] = ["/"]
options[:percentage] = 20
OptionParser.new do |opts|
  opts.banner = "Usage: diskspace [OPTIONS]"
  opts.on("-k KEY","--pagerdutykey=KEY", "Your Pagerduty key") do |pagerdutykey|
    options[:pagerdutykey] = pagerdutykey
  end
  opts.on("-p N", "--period N", "Seconds between checks") do |period|
    options[:period] = period.to_i
  end
  opts.on("-a N", "--percent N", "Percentage if lower than of diskspace to alert about") do |percentage|
    options[:percentage] = percentage.to_i
  end
  opts.on("-v PATH,PATH,PATH", "--volumes=PATH,PATH,PATH", Array, "Paths of volumes to check") do |volumes|
    options[:volumes] = volumes
  end
end.parse!

# Basic forever loop
loop do
  sleep(options[:period])
  # Check each path
  options[:volumes].each do |vol|
    # stat the volume
    stat = Sys::Filesystem.stat(vol)
    percent_free = ((stat.bytes_free.to_f / stat.bytes_total.to_f)*100).round
    puts "'#{vol}' is #{percent_free}% free.\n"
    # If there currently is an incident, check to see if it's ok now and clear it
    if @incident != nil
      puts "There's currently an alert.\n"
      if percent_free >= options[:percentage]
        puts "Clearing alert.\n"
        begin 
          @incident.clear
        rescue => e
          $stderr.puts "Unable to contact Pagerduty!"
          next
        end
        @incident = nil
      end
    # Or there isn't an incident, so do a normal check and create an incident if not ok
    else
      if percent_free <= options[:percentage] 
        pagerduty = Pagerduty.new(options[:pagerdutykey])
        begin
          @incident = pagerduty.trigger("#{ options[:hostname] } path '#{vol}' is at #{ percent_free } % free diskspace ")
        rescue => e
          $stderr.puts "Unable to contact Pagerduty!"
        end
      end
    end
  end
end
