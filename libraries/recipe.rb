module Discovery
  module Recipe

    def discovery_search(role='', args={})
      Discovery.search(role, {:node => node}.merge(args))
    end

    def discovery_ipaddress(args={})
      Discovery.ipaddress({:node => node}.merge(args))
    end
    
  end
end

Chef::Recipe.send(:include, Discovery::Recipe)
