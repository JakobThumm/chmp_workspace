#!/bin/bash
# Rebuild the workspace after edits. Run INSIDE the container.
#
# With --symlink-install, edits to node *.py files are live after re-sourcing the
# overlay -- no rebuild needed. Rebuild only after changes to setup.py / package.xml
# / entry_points or to .msg definitions (uq_msgs).

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WS_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

source /opt/ros/jazzy/setup.bash
if [ -f "$WS_ROOT/.venv/bin/activate" ]; then
    # shellcheck disable=SC1091
    source "$WS_ROOT/.venv/bin/activate"
fi

cd "$WS_ROOT"
colcon build --symlink-install --packages-up-to chmp_inference

echo ""
echo "Build complete. Re-source the overlay:  source $WS_ROOT/install/setup.bash"
