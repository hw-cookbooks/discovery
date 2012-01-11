module Discovery
  class << self

    def ipaddress( node = nil, type = :local)
      Chef::Log.debug "ipaddress[#{type}]: attempting to determine #{type} ip address for #{node.name}"

      [ node.cloud.send("#{type}_ipv4"),
        node.ipaddress ].detect do |attribute|
        begin
          ip = attribute
        rescue StandardError => standard_error
          Chef::Log.debug "ipaddress: error #{standard_error}"
          nil
        rescue Exception => exception
          Chef::Log.debug "ipaddress: exception #{exception}"
          nil
        end
      end
    end

  end
end

