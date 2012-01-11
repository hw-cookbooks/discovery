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
