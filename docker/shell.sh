#!/bin/bash
# Open an interactive shell in the running chmp_workspace container.

set -e

USERNAME=${USERNAME:-$(whoami)}

echo "Opening shell in chmp-ros2-cuda as user '$USERNAME'..."
docker exec -it -u "$USERNAME" chmp-ros2-cuda bash
