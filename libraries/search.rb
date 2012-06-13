require "chef/search/query"
require "chef/config"
require "chef/log"

module Discovery
  class << self
    def search( role = "", options = {})
      raise ArgumentError.new("You must pass a role") if role.empty?
      raise ArgumentError.new("Options must be a hash") unless options.respond_to? :has_key?
      raise ArgumentError.new("Options does not contain a node key") unless options.has_key? :node

      options[:environment_aware] ||= false

      Chef::Log.debug "discovery: doing enviornment aware search" if options.has_key? :environment_aware and options[:environment_aware]

      results = []

      case options.has_key? :environment_aware and options[:environment_aware]
      when true
        [ "chef_environment:#{options[:node].chef_environment} AND roles:#{role}",
          "chef_environment:#{options[:node].chef_environment} AND role:#{role}" ]
      when false
        [ "roles:#{role}",
          "role:#{role}" ]
      end.detect do |search|
        results = _query(search)
        next if results.empty?
        results
      end

      if results.empty?
        if options[:node].run_list.include? "role[#{role}]" or options[:node].roles.include? role
          Chef::Log.debug "discovery: empty results and local node includes role #{role}, falling back to local"
          return options[:node]
        else
          Chef::Log.debug "discovery: node run_list: #{options[:node].run_list.inspect}, roles: #{options[:node].roles.inspect}"
          raise RuntimeError.new("No response from search and no local node did not include #{role}") if results.empty?
        end
      end

      if results.first == options[:node]
        Chef::Log.warn "discovery: search response is ourself, connecting to localhost"
      end

      return results.first
    end

    def all( role = "", options = {})
      raise ArgumentError.new("You must pass a role") if role.empty?
      raise ArgumentError.new("Options must be a hash") unless options.respond_to? :has_key?
      raise ArgumentError.new("Options must contain a node key") unless options.has_key? :node

      options[:environment_aware] = false unless options.key? :environment_aware
      options[:empty_ok] = false unless options.key? :empty_ok
      options[:remove_self] = true unless options.key? :remove_self
      options[:minimum_response_time] = false unless options.key? :minimum_response_time

      Chef::Log.debug "discovery: doing enviornment aware search" if options[:environment_aware]

      results = []

      case options[:environment_aware]
      when true
        [ "chef_environment:#{options[:node].chef_environment} AND (roles:#{role} OR role:#{role})" ]
      when false
        [ "roles:#{role} OR role:#{role}" ]
      end.each do |search|
        results = _query(search)
      end

      results.delete(options[:node]) if options[:remove_self]
      results.reject! {|o| (Time.now.to_f - o.ohai_time) > options[:minimum_response_time]} if options[:minimum_response_time]

      if results.empty?
        if !options[:remove_self] && (options[:node].run_list.include? "role[#{role}]" or options[:node].roles.include? role)
          Chef::Log.debug "discovery: empty results and local node includes role #{role}, falling back to local"
          return [options[:node]]
        elsif options[:empty_ok]
          return []
        else
          Chef::Log.debug "discovery: node run_list: #{options[:node].run_list.inspect}, roles: #{options[:node].roles.inspect}"
          raise RuntimeError.new("No nodes matched on search and local node did not include #{role}") if results.empty?
        end
      end

      if results.include? options[:node]
        Chef::Log.warn "discovery: search response includes ourself, connecting to localhost"
      end

      return results
    end

    private

    def _query( string )
      results = []
      Chef::Log.debug "discovery: performing search for: #{string}"
      Chef::Search::Query.new.search(:node, string) { |o| results << o }

      ohai_times = results.map do |node|
        [ node.name, node.ohai_time ]
      end

      Chef::Log.debug "discovery: found nodes with recent check in: #{ohai_times.inspect}"

      results.sort do |node_a, node_b|
        node_a.ohai_time <=> node_b.ohai_time
      end
    end

  end
end
