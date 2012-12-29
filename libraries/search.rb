require "chef/search/query"
require "chef/config"
require "chef/log"

module Discovery
  class DiscoveryError < RuntimeError; end
  class << self
    def search( role_or_search = "", options = {})
      # All returns all of the nodes, they're already sorted by
      # ohai_time, so grab the first one.
      all(role_or_search, options).first
    end

    def all( role_or_search = "", options = {})
      raise ArgumentError.new("You must pass a role") if role_or_search.empty?
      raise ArgumentError.new("Options must be a hash") unless options.respond_to? :has_key?
      raise ArgumentError.new("Options must contain a node key") unless options.has_key? :node

      options[:environment_aware] = false unless options.key? :environment_aware
      options[:empty_ok] = false unless options.key? :empty_ok
      options[:remove_self] = true unless options.key? :remove_self
      options[:local_fallback] = false unless options.key? :local_fallback
      options[:raw_search] = false unless options.key? :raw_search
      options[:minimum_response_time_sec] = 60 * 60 * 24 unless options.key? :minimum_response_time_sec

      Chef::Log.debug "discovery: doing enviornment aware search" if options[:environment_aware]

      results = []
      search = []

      if options[:environment_aware]
        search << "chef_environment:#{options[:node].chef_environment}"
      end

      if options[:raw_search]
        search << "(#{role_or_search})"
      else
        # TODO: Do we need to search both role and roles? Is just roles sufficent?
        search << "(roles:#{role_or_search} OR role:#{role_or_search})"
      end

      results = query(search.join(' AND '))
      ResultProcessor.new(results, options, role_or_search).filter
    end

    private
    def query( string )
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

  class ResultProcessor
    attr_accessor :results, :options, :role

    def initialize(results = [], options = {}, role)
      @results = results
      @options = options
      @role = role
    end

    def fallback_to_local
      if empty? && !options[:raw_search] && options[:node].roles.include?(role)
        Chef::Log.debug "discovery: node run_list: #{options[:node].run_list.inspect}, roles: #{options[:node].roles.inspect}"
        results << options[:node]
      end
    end

    def check_empty_and_raise
      raise DiscoveryError.new("discovery: no nodes matched on smart search for #{role}. options: #{options.inspect}") if empty?
    end

    def empty?
      results.empty?
    end

    def remove_stale
      results.reject! {|o| (Time.now.to_f - o.ohai_time) > options[:minimum_response_time_sec]}
    end

    def remove_self
      results.reject!{ |n| n.name == options[:node].name }
    end

    def filter
      remove_stale if options[:minimum_response_time_sec]
      remove_self if options[:remove_self]
      fallback_to_local if options[:local_fallback]
      check_empty_and_raise unless options[:empty_ok]

      results
    end
  end

end
