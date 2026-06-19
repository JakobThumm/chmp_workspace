#!/bin/bash
# Stop and remove the chmp_workspace container.

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Stopping and removing chmp-workspace container..."
cd "$SCRIPT_DIR"
docker compose down

echo ""
echo "Stopped. Start again with ./run.sh"
