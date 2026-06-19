#!/bin/bash
# Build the chmp_workspace Docker image (CUDA 12.8 + ROS2 Jazzy system layer).

set -e

# Export current user info so the image's user matches the host (UID/GID).
export USER_ID=$(id -u)
export GROUP_ID=$(id -g)
export USERNAME=$(whoami)

echo "Building chmp-workspace image (CUDA 12.8 + ROS2 Jazzy)..."
echo "User: $USERNAME (UID: $USER_ID, GID: $GROUP_ID)"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"
docker compose build

echo ""
echo "Build complete! Next: ./run.sh"
