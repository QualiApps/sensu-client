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

  def get_cpuacct_stats 
     step = 0
     ENV['DOCKER_HOST'] = config[:docker_host]
     c_names = get_containers_name
     cpuacct_stat = []
     info = []
    `docker ps --no-trunc`.each_line do |ps|
      next if ps =~ /^CONTAINER/
      container, image = ps.split /\s+/
      container_name = ps.split.last
      #prefix = "#{container}"
      prefix = c_names[step]
      step = step + 1
      ['cpuacct.stat','cpuacct.usage'].each do |stat|
        f = [config[:cgroup_path], "cpuacct/system.slice/docker-"+container+".scope", stat].join('/')
        File.open(f, "r").each_line do |l|
          k, v = l.chomp.split /\s+/
          if (v != nil) then
            key = [prefix, stat, k].join('.')
            info.push(v)
          else
            key = [prefix, stat].join('.')
            info.push(k)
          end
          cpuacct_stat.push(key)
        end
      end
    end
    return Hash[cpuacct_stat.zip(info.map(&:to_i))].reject {|key, value| value == nil }
  end

  def run
    cpuacct_stat1 = get_cpuacct_stats
    sleep(1)
    cpuacct_stat2 = get_cpuacct_stats
    cpu_metrics = cpuacct_stat2.keys
    
    # diff cpu usage in last second
    cpu_sample_diff = Hash[cpuacct_stat2.map { |k, v| [k, v - cpuacct_stat1[k]] }]

    step = 0;
    total = 0.0
    cpu_metrics.each do |metric|
      container, cpuacct, stat = metric.split /\./  
      
      if (stat != "usage") then
        step = step + 1
        key = [container, cpuacct, 'usage'].join('.')
	metric_val = 0.0
	if (cpu_sample_diff[key].to_i != 0) then
            metric_val = sprintf("%.03f", cpu_sample_diff[metric].to_f/(cpu_sample_diff[key].to_f/1000/1000/1000))
            total = total + metric_val.to_f
        end
        print container, " ", "#{config[:scheme]}.#{metric}", " ", metric_val, " ", Time.now.to_i, "\n"
        if (step % 2 == 0) then
            print container, " ", "#{config[:scheme]}.#{container}.#{cpuacct}.#{stat}.total", " ", sprintf("%.03f", total), " ", Time.now.to_i, "\n"
            total = 0.0
        end 
      end
    end
    ok
  end
end
