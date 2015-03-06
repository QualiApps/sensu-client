#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class DockerContainerMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.docker"

  option :cgroup_path,
    :description => "path to cgroup mountpoint",
    :short => "-c PATH",
    :long => "--cgroup PATH",
    :default => "/sys/fs/cgroup"

  option :docker_host,
         description: 'docker host',
         short: '-H DOCKER_HOST',
         long: '--docker-host DOCKER_HOST',
         default: "tcp://#{ENV['NODE_IP']}:2375"

  def get_mem_stats
     mem_stat = []
     info = []
     ENV['DOCKER_HOST'] = config[:docker_host]
    `docker ps --no-trunc`.each_line do |ps|
      next if ps =~ /^CONTAINER/
      container, image = ps.split /\s+/
      prefix = "#{container}"

      ['memory.stat'].each do |stat|
        f = [config[:cgroup_path], "memory/system.slice/docker-"+container+".scope", stat].join('/')
        File.open(f, "r").each_line do |l|
          k, v = l.chomp.split /\s+/
          if (v != nil) then
            key = [prefix, stat, k].join('.')
            info.push(v)
          else
            key = [prefix, stat].join('.')
            info.push(k)
          end
          mem_stat.push(key)
        end
      end
    end
    return Hash[mem_stat.zip(info.map(&:to_i))].reject {|key, value| value == nil }
  end

  def get_mem_usage
     mem_stat = []
     info = []
     ENV['DOCKER_HOST'] = config[:docker_host]
    `docker ps --no-trunc`.each_line do |ps|
      next if ps =~ /^CONTAINER/
      container, image = ps.split /\s+/
      prefix = "#{container}"

      ['memory.usage_in_bytes'].each do |stat|
        f = [config[:cgroup_path], "memory/system.slice/docker-"+container+".scope", stat].join('/')
        File.open(f, "r").each_line do |value|
          key = [prefix, stat, "usage"].join('.')
          info.push(value)
          mem_stat.push(key)
        end
      end
    end
    return Hash[mem_stat.zip(info.map(&:to_i))].reject {|key, value| value == nil }
  end


  def metrics_hash                                                                                            
    mem = {}                                                                                                  
    get_mem_stats.each do |line|                                                                        
      puts line
      mem['total']     = line.split(/\s+/)[1].to_i * 1024 if line.match(/^MemTotal/)                          
      mem['free']      = line.split(/\s+/)[1].to_i * 1024 if line.match(/^MemFree/)                           
      mem['buffers']   = line.split(/\s+/)[1].to_i * 1024 if line.match(/^Buffers/)                           
      mem['cached']    = line.split(/\s+/)[1].to_i * 1024 if line.match(/^Cached/)                            
      mem['swapTotal'] = line.split(/\s+/)[1].to_i * 1024 if line.match(/^SwapTotal/)                         
      mem['swapFree']  = line.split(/\s+/)[1].to_i * 1024 if line.match(/^SwapFree/)                          
      mem['dirty']     = line.split(/\s+/)[1].to_i * 1024 if line.match(/^Dirty/)                             
    end                                                                                                       
    mem                                                                                                       
  end 

  def run                                                                                                     
    mem = get_mem_usage                                                                                      
                                                                                                              
    mem.each do |k, v|                                                                                        
      output "#{config[:scheme]}.#{k}", v                                                                     
    end                                                                                                       
                                                                                                              
    ok                                                                                                        
  end 
end 
