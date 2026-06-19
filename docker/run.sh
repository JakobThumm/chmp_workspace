#!/bin/bash
# Start the chmp_workspace container (detached; runs the Zenoh router).

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export USER_ID=$(id -u)
export GROUP_ID=$(id -g)
export USERNAME=$(whoami)

echo "Starting chmp-workspace container..."
echo "User: $USERNAME (UID: $USER_ID, GID: $GROUP_ID)"

cd "$SCRIPT_DIR"
docker compose up -d

echo ""
echo "Container started with the Zenoh router active (listening on 0.0.0.0:7447)."
echo ""
echo "Open a shell:        ./shell.sh"
echo "First-time setup:    ./shell.sh  ->  /workspace/scripts/setup_workspace.sh"
echo "View router logs:    docker logs chmp-ros2-cuda"
echo "Stop the container:  ./stop.sh"
