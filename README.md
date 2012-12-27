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

All
---

You can use the #all method to locate all nodes with a role,
optionally restricted to the environment.

Additional options:

``` ruby
hosts = Discovery.all("base",
                      :node => node,
                      :environment_aware => true,
                      :empty_ok => false,
                      :remove_self => true,
                      :minimum_response_time => false)
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


Recipe DSL
----------

Recipe DSL versions of the search, all and ipaddress methods are avaialble for the class; using them means you do not need to explicitly pass the node:

* discovery_search

``` ruby
# Note omission of :node => node 
host = discovery_search("base",
                        :environment_aware => true,
                        :empty_ok => false,
                        :remove_self => true,
                        :minimum_response_time => false)
```

* discovery_all

``` ruby
hosts = discovery_all(...)
```

* discovery_ipaddress

``` ruby
host = discovery_search(...)
ipaddress = discovery_ipaddress(:remote_node = host)
```

Raw attribute search
--------------------

Perform raw attribute searching instead of just restricting search to
role names:

```ruby
host = Discovery.search("attr_name:attr_value",
                        :node => node,
                        :environment_aware => false,
                        :raw_search => true)
```
