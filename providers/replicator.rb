#
# Cookbook Name:: aem
# Provider:: replicator
#
# Copyright 2012, Tacit Knowledge, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#This provider adds or removes replication agents from an AEM instance

require 'erb'

action :add do
  hosts = new_resource.remote_hosts
  local_user = new_resource.local_user
  local_password = new_resource.local_password
  local_port = new_resource.local_port
  hosts = new_resource.remote_hosts
  role = new_resource.cluster_role
  cluster_name = new_resource.cluster_name
  type = new_resource.type

  raise "No command specified for replicator type: #{type}. See node attribute :aem->" +
    ":commands->:replicators." unless node[:aem][:commands][:replicators][type][:add]

  case type
    when :publish
      aem_instance = :publish
    when :flush
      aem_instance = :dispatcher
    when :agent
      aem_instance = :publish
    end

  if new_resource.dynamic_cluster
    log "Finding replication hosts dynamically..."
    hosts = []
    search(:node, %Q(role:"#{role}" AND aem_cluster_name:"#{cluster_name}")) do |n|
      log "Found host: #{n[:fqdn]}"
      hosts << {
        :ipaddress => n[:ipaddress],
        :port => n[:aem][aem_instance][:port],
        :user => n[:aem][aem_instance][:admin_user],
        :password => n[:aem][aem_instance][:admin_password],
        :name => n[:fqdn]
      }
    end
    hosts.sort! { |a,b| a[:name] <=> b[:name] }
  end

  counter = 0
  hosts.each do |h|
    instance = counter > 0 ? counter.to_s : ""
    cmd = ERB.new(node[:aem][:commands][:replicators][type][:add]).result(binding)

    log "Adding replication agent with command: #{cmd}"
    runner = Mixlib::ShellOut.new(cmd)
    runner.run_command
    runner.error!
    counter += 1
  end
end

action :remove do
  hosts = new_resource.remote_hosts
  local_user = new_resource.local_user
  local_password = new_resource.local_password
  local_port = new_resource.local_port
  hosts = new_resource.remote_hosts
  role = new_resource.cluster_role
  cluster_name = new_resource.cluster_name
  type = new_resource.type

  raise "No command specified for replicator type: #{type}. See node attribute :aem->" +
    ":commands->:replicators." unless node[:aem][:commands][:replicators][type][:remove]

  case type
    when :publish
      aem_instance = :publish
      agent = "publish"
    when :flush
      aem_instance = :dispatcher
    when :agent
      aem_instance = :publish
      agent = "author"
    end

  if new_resource.dynamic_cluster
    log "Finding replication hosts dynamically..."
    hosts = []
    search(:node, %Q(role:"#{role}" AND aem_cluster_name:"#{cluster_name}")) do |n|
      log "Found host: #{n[:fqdn]}"
      hosts << {
        :ipaddress => n[:ipaddress],
        :port => n[:aem][aem_instance][:port],
        :user => n[:aem][aem_instance][:admin_user],
        :password => n[:aem][aem_instance][:admin_password],
        :name => n[:fqdn]
      }
    end
    hosts.sort! { |a,b| a[:name] <=> b[:name] }

    if type == :agent
      cmd = ERB.new(node[:aem][:commands][:replicators][type][:list]).result(binding)

      log "Creating list of replication agents wth command: #{cmd}"
      runner = Mixlib::ShellOut.new(cmd)
      runner.run_command
      runner.error!

      list = JSON.parse(runner.stdout)
      all_agents = []
      list["agents.#{agent}"].keys.each do |key|
        all_agents << key unless key =~ /jcr/
      end

      counter = 0
      agents = []
      hosts.each do |h|
        instance = counter > 0 ? counter.to_s : ""
        agents << "#{aem_instance}#{instance}"
      end

      hosts = all_agents - agents
    end

  end

  counter = 0
  hosts.each do |h|
    instance = counter > 0 ? counter.to_s : ""
    cmd = ERB.new(node[:aem][:commands][:replicators][type][:remove]).result(binding)

    log "Removing replication agent with command: #{cmd}"
    runner = Mixlib::ShellOut.new(cmd)
    runner.run_command
    runner.error!
    counter += 1
  end
end

