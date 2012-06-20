module Discovery
  module Recipe

    %w{search all}.each do |dsl_method|
      define_method("discovery_#{dsl_method}") do |role='', args={}|
        Discovery.send(dsl_method, role, {:node => node}.merge(args))
      end
    end

    def discovery_ipaddress(args={})
      Discovery.ipaddress({:node => node}.merge(args))
    end

  end
end

Chef::Recipe.send(:include, Discovery::Recipe)
Chef::Resource.send(:include, Discovery::Recipe)
