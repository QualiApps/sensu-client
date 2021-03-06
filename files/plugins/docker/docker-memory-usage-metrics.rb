#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'time'

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

  def get_containers_name
    names = []
    `docker ps`.each_line do |ps|
      next if ps =~ /^CONTAINER/
      names.push(ps.split.last)
    end
    return names
  end

  def get_cgroup(container, stat_file, mount)
    # We try with different cgroups so that it works even if only one is properly working
    mountpoint = [config[:cgroup_path], mount].join('/')

    stat_file_path_lxc = [mountpoint, "lxc"].join('/')
    stat_file_path_docker = [mountpoint, "docker"].join('/')
    stat_file_path_coreos = [mountpoint, "system.slice"].join('/')
    if Dir.exists?(stat_file_path_lxc)
      return [stat_file_path_lxc, container, stat_file].join('/')
    elsif Dir.exists?(stat_file_path_docker)
      return [stat_file_path_docker, container, stat_file].join('/')
    elsif Dir.exists?(stat_file_path_coreos)
      return [stat_file_path_coreos, "docker-"+container+".scope", stat_file].join('/')
    end
  end

  def get_mem_stats
     step = 0
     ENV['DOCKER_HOST'] = config[:docker_host]
     c_names = get_containers_name
     mem_stat = []
     info = []
    `docker ps --no-trunc`.each_line do |ps|
      next if ps =~ /^CONTAINER/
      container, image = ps.split /\s+/
      #prefix = "#{container}"
      prefix = c_names[step]
      step = step + 1

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
     step = 0
     #ENV['DOCKER_HOST'] = config[:docker_host]
     c_names = get_containers_name
     mem_stat = []
     info = []
    `docker ps --no-trunc`.each_line do |ps|
      next if ps =~ /^CONTAINER/
      container, image = ps.split /\s+/
      #prefix = "#{container}"
      prefix = c_names[step]
      step = step + 1
      ['memory.usage_in_bytes'].each do |stat|
        #f = [config[:cgroup_path], "memory/system.slice/docker-"+container+".scope", stat].join('/')
        f = get_cgroup(container, stat, "memory")
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
      filter = k.split "."
      print filter[0], " ", "#{config[:scheme]}.#{k}", " ", v, " ", Time.now.to_i, "\n"                                                                     
    end
    ok
  end
end
