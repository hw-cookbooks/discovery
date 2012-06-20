require "chef/search/query"
require "chef/config"
require "chef/log"

module Discovery
  class << self
    def search( role = "", options = {})
      # All returns all of the nodes, they're already sorted by
      # ohai_time, so grab the first one.
      all(role, options).first
    end

    def all( role = "", options = {})
      raise ArgumentError.new("You must pass a role") if role.empty?
      raise ArgumentError.new("Options must be a hash") unless options.respond_to? :has_key?
      raise ArgumentError.new("Options must contain a node key") unless options.has_key? :node

      options[:environment_aware] = false unless options.key? :environment_aware
      options[:empty_ok] = false unless options.key? :empty_ok
      options[:remove_self] = true unless options.key? :remove_self
      options[:local_fallback] = false unless options.key? :local_fallback
      options[:minimum_response_time_sec] ||= 60 * 60 * 24

      Chef::Log.debug "discovery: doing enviornment aware search" if options[:environment_aware]

      results = []

      case options[:environment_aware]
      when true
        [ "chef_environment:#{options[:node].chef_environment} AND (roles:#{role} OR role:#{role})" ]
      when false
        [ "roles:#{role} OR role:#{role}" ]
      end.each do |search|
        results = query(search)
      end

      ResultProcessor.new(results, options).filter
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
    attr_accessor :results, :options

    def initialize(results = [], options = {})
      @results = results
      @options = options
    end

    def fallback_to_local
      if empty? && options[:node].roles.include?(role)
        Chef::Log.debug "discovery: node run_list: #{options[:node].run_list.inspect}, roles: #{options[:node].roles.inspect}"
        results << options[:node]
      end
    end

    def check_empty_and_raise
      raise RuntimeError.new("No nodes matched on search. Options: #{options.inspect}") if empty?
    end

    def empty?
      results.empty?
    end

    def remove_stale
      results.reject! {|o| (Time.now.to_f - o.ohai_time) > options[:minimum_response_time_sec]}
    end

    def remove_self
      results.delete(options[:node])
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
