require "chef/platform"
require "chef/node"
require "fauxhai"

require_relative "../../../libraries/ipaddress"

describe Discovery do

  let(:ohai_data) do
    Mash.new(Fauxhai.mock(:platform => "centos", :version => "6.5").data)
  end

  let(:attr_data) do
    Mash.new
  end

  let(:node) do
    Chef::Node.new.tap do |node|
      node.name("foobar")
      node.consume_external_attrs(ohai_data, attr_data)
    end
  end

  let(:remote_node) do
    Chef::Node.new.tap do |node|
      node.name("bazqux")
      node.consume_external_attrs(ohai_data, attr_data)
    end
  end

  describe ".provider_for_node" do
    let(:provider) { Discovery.provider_for_node(node) }

    it "raises an exception if a node is not provided" do
      expect { Discovery.provider_for_node }.to raise_error
    end

    it "detects the cloud provider" do
      attr_data[:cloud] = Mash.new(:provider => "ec2")
      expect(provider).to eq("ec2")
    end

    it "returns nil when no provider is found" do
      expect(provider).to eq(nil)
    end
  end

  describe ".region_for_ec2_node" do
    let(:region) { Discovery.region_for_ec2_node(node) }

    it "raises an exception if a node is not provided" do
      expect { Discovery.region_for_ec2_node }.to raise_error
    end

    it "detects the region for an ec2 node" do
      attr_data[:ec2] = Mash.new(:placement_availability_zone => "us-east-1d")
      expect(region).to eq("us-east-1")
    end

    it "returns nil when no ec2 attributes are populated" do
      expect(region).to eq(nil)
    end
  end

  describe ".ipaddress" do
    let(:opts) do
      {
        :node => node,
        :remote_node => remote_node,
      }
    end

    let(:ipaddress) { Discovery.ipaddress(opts) }

    it "requires an options hash" do
      expect { Discovery.ipaddress("boom") }.to raise_error
    end

    it "requires a node option" do
      opts.delete(:node)
      expect { ipaddress }.to raise_error
    end

    it "requires a remote node option" do
      opts.delete(:remote_node)
      expect { ipaddress }.to raise_error
    end

    it "requires a valid type option" do
      opts[:type] = "nope"
      expect { ipaddress }.to raise_error
    end

    it "requires a the type option be a symbol" do
      opts[:type] = "local"
      expect { ipaddress }.to raise_error
    end

    it "works" do
      attr_data[:cloud] = Mash.new(:local_ipv4 => "127.0.0.1")
      expect(ipaddress).to eq("127.0.0.1")
    end

    it "will return a public address if node providers do not match" do
      attr_data[:cloud] = Mash.new(:provider => "ec2", :public_ipv4 => "127.0.0.1")
      opts[:remote_node].set[:cloud][:provider] = "rackspace"
      expect(ipaddress).to eq("127.0.0.1")
    end

    it "will return a local address if node providers match and are not ec2" do
      attr_data[:cloud] = Mash.new(
        :provider => "rackspace",
        :local_ipv4 => "127.0.0.1"
      )
      expect(ipaddress).to eq("127.0.0.1")
    end

    it "will return a public address if node regions do not match" do
      attr_data[:cloud] = Mash.new(
        :provider => "ec2",
        :public_ipv4 => "127.0.0.1",
        :placement_availability_zone => "us-east-1d"
      )
      opts[:remote_node].set[:ec2][:placement_availability_zone] = "us-west-1a"
      expect(ipaddress).to eq("127.0.0.1")
    end

    it "will return a local address if node regions match" do
      attr_data[:cloud] = Mash.new(
        :provider => "ec2",
        :local_ipv4 => "127.0.0.1",
        :placement_availability_zone => "us-east-1d"
      )
      expect(ipaddress).to eq("127.0.0.1")
    end

    it "will fallback to node.ipaddress if the cloud attribute is not set" do
      ohai_data[:ipaddress] = "192.168.2.42"
      expect(ipaddress).to eq("192.168.2.42")
    end

    it "will fallback to node.ipaddress if the cloud ipv4 address is not set" do
      ohai_data[:ipaddress] = "192.168.2.42"
      attr_data[:cloud] = Mash.new(
        :provider => "ec2",
        :placement_availability_zone => "us-east-1d"
      )
      expect(ipaddress).to eq("192.168.2.42")
    end
  end
end
