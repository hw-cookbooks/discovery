module Discovery
  class << self

    def provider_for_node(node = nil)
      raise "Must pass a node" unless node
      if node.has_key? :cloud and
          node.cloud.has_key? :provider
        node.cloud.provider
      else
        nil
      end
    end

    def region_for_ec2_node(node)
      raise "Must pass a node" unless node
      if node.has_key? :ec2 and
          node.ec2.has_key? :placement_availability_zone
        node[:ec2][:placement_availability_zone].gsub(/(\d+).+/,'\1')
      else
        nil
      end
    end

    def ipaddress(options = {})
      raise "Options must be a hash" unless
        options.respond_to? :has_key?
      raise "Options does not contain a node key" unless
        options.has_key? :node
      raise "Options does not contain a remote_node key" unless
        options.has_key? :remote_node
      raise "Options type is invalid" if
        options.has_key? :type and not
          [:local, :public].include?(options[:type])

      options[:type] ||=
        if provider_for_node(options[:remote_node]) == provider_for_node(options[:node])
          if provider_for_node(options[:node]) == "ec2"
            if region_for_ec2_node(options[:node]) == region_for_ec2_node(options[:remote_node])
              :local
            else
              :public
            end
          else
            :local
          end
        else
          :public
        end

      Chef::Log.debug "ipaddress[#{options[:type]}]: attempting to determine ip address for #{options[:node].name}"

      cloud_ipv4 = options[:remote_node][:cloud]["#{options[:type]}_ipv4"] rescue nil
      cloud_ipv4 || options[:remote_node][:ipaddress]
    end

  end
end
