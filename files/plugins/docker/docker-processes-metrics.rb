#! /usr/bin/env ruby
#
#   docker-container-metrics
#
# DESCRIPTION:
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Michal Cichra. Github @mikz
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'pathname'
require 'sys/proctable'

class DockerContainerMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "docker.#{Socket.gethostname}"

  option :cgroup_path,
         description: 'path to cgroup mountpoint',
         short: '-c PATH',
         long: '--cgroup PATH',
         default: '/sys/fs/cgroup'

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

  def run
    container_metrics
    ok
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

  def container_metrics
    cgroup = Pathname(config[:cgroup_path]).join('cpu/system.slice')

    timestamp = Time.now.to_i
    ps = Sys::ProcTable.ps.group_by(&:pid)
    sleep(1)
    ps2 = Sys::ProcTable.ps.group_by(&:pid)

    fields = [:rss, :vsize, :nswap, :pctmem]

    #ENV['DOCKER_HOST'] = config[:docker_host]
    c_names = get_containers_name
    step = 0
    containers = `docker ps --quiet --no-trunc`.split("\n")

    containers.each do |container|
      cname = c_names[step]
      step = step + 1
      f = get_cgroup(container, "cgroup.procs", "cpu")
      #pids = cgroup.join("docker-"+container+".scope").join('cgroup.procs').readlines.map(&:to_i)
      pids = Pathname(f).readlines.map(&:to_i)

      processes = ps.values_at(*pids).flatten.compact.group_by(&:comm)
      processes2 = ps2.values_at(*pids).flatten.compact.group_by(&:comm)

      processes.each do |comm, process|
        prefix = cname + " " + "#{config[:scheme]}.#{container}.#{comm}"
        fields.each do |field|
          output "#{prefix}.#{field}", process.map(&field).reduce(:+), timestamp
        end
        # this check requires a lot of permissions, even root maybe?
        output "#{prefix}.fd", process.map { |p| p.fd.keys.count }.reduce(:+), timestamp

        second = processes2[comm]
        cpu = second.map { |p| p.utime + p.stime }.reduce(:+) - process.map { |p| p.utime + p.stime }.reduce(:+)
        output "#{prefix}.cpu", cpu, timestamp
      end
    end
    ok
  end
end
