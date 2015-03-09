#! /usr/bin/env ruby
#  encoding: UTF-8
#
#   check-ram
#
# DESCRIPTION:
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#
# NOTES:

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckRAM < Sensu::Plugin::Check::CLI
  option :warn,
         short: '-w WARN',
         proc: proc(&:to_i),
         default: 10

  option :crit,
         short: '-c CRIT',
         proc: proc(&:to_i),
         default: 5

  def metrics_hash
    mem = {}
    meminfo_output.each_line do |line|
      mem['total']     = line.split(/\s+/)[1].to_i * 1024 if line.match(/^MemTotal/)
      mem['free']      = line.split(/\s+/)[1].to_i * 1024 if line.match(/^MemFree/)
      mem['buffers']   = line.split(/\s+/)[1].to_i * 1024 if line.match(/^Buffers/)
      mem['cached']    = line.split(/\s+/)[1].to_i * 1024 if line.match(/^Cached/)
    end
    
    mem['used'] = mem['total'] - mem['free']
    mem['usedWOBuffersCaches'] = mem['used'] - (mem['buffers'] + mem['cached'])
    mem['freeWOBuffersCaches'] = mem['free'] + (mem['buffers'] + mem['cached'])

    mem
  end

  def meminfo_output
    File.open('/proc/meminfo', 'r')
  end

  def run
    memory = metrics_hash

    unknown 'invalid percentage' if config[:crit] > 100 || config[:warn] > 100
    percents_left = memory['freeWOBuffersCaches'] * 100 / memory['total']
    message "#{percents_left}% free RAM left"

    critical if percents_left < config[:crit]
    warning if percents_left < config[:warn]
    ok
  end
end
