# Automating-multi-service-dependency-updates
This script streamlines the process of updating shared dependencies across multiple services within a distributed or microservices-based architecture. It automatically detects outdated packages or modules, applies consistent version updates across designated repositories, and can optionally trigger build pipelines or create pull requests.

# Update both release and develop
`./dependency_updater.sh -a common-lib -v 1.2.3 -b both`

# Update only develop
`./dependency_updater.sh -a common-lib -v 1.2.3 -b develop`

# Update only release
`./dependency_updater.sh -a common-lib -v 1.2.3 -b release`

# Specify custom directory
`./dependency_updater.sh -a common-lib -v 1.2.3 -b both -d /path/to/services`
