Discovery Library
=================

Search
------

You can use the #search method to locate a role, optionally
restricted to the environment.

It will fall back to searching the local nodes run_list for roles, so
you can have less logic flow in recipes.

``` ruby
host = Discovery.search("any_role",
                        :node => node,
                        :environment_aware => false)
```

ipaddress
---------

You can use the #ipaddress method to automatically grab a prioritised
ipaddress from a node.

The remote node will be compared against the same node, if any are in
any clouds detected by ohai (and they are in the same cloud) the local
ipv4 will be returned.

You can optionally supply a type argument specifying which ipaddress
you would like.

``` ruby
ipaddress = Discovery.ipaddress(:remote_node => host,
                                :node => node)
```

``` ruby
local_ipv4 = Discovery.ipaddress(:remote_node => host,
                                 :node => node,
                                 :type => :local)
```                                 

``` ruby
public_ipv4 = Discovery.ipaddress(:remote_node => host,
                                 :node => node,
                                 :type => :public)
```
