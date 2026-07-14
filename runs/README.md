# Durable local run bundles

LUCAS writes completed, checksummed run bundles here by default. Unlike `tmp/`,
this directory is not a disposable preview cache. The permanent application in
`dashboard/` can load a run's dashboard-data JSON without copying the dashboard
into every bundle.

Generated bundles may become large. Decide deliberately whether an individual
bundle belongs in Git, an object store, or a publication archive; do not delete
or publish it merely because it is in this directory.
