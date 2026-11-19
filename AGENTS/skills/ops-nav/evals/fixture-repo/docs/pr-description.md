This PR is not a refactor. It is a rewrite of the cache layer.

It is worth noting that the change is crucial. We leverage the existing TTL helper, which is
robust, and we simply reduce the number of calls. The result is provably better.
