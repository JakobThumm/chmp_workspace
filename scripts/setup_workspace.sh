#!/bin/bash
# One-time workspace setup. Run INSIDE the container from /workspace:
#   ./shell.sh   ->   /workspace/scripts/setup_workspace.sh
#
# It: imports vcs repos -> creates the venv -> installs the core lib + GPU stack
# -> colcon-builds the workspace. Safe to re-run (idempotent-ish).

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WS_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
VENV="$WS_ROOT/.venv"
CORE=/opt/chmp

cd "$WS_ROOT"

echo "==> Sourcing ROS2 Jazzy"
source /opt/ros/jazzy/setup.bash

# 1) Pull vcs-managed source repos (uq_msgs, optionally realsense) into src/.
echo "==> vcs import src < chmp_workspace.repos"
mkdir -p src
vcs import src < chmp_workspace.repos

# 2) chmp_inference is a host bind mount, not vcs-imported. Fail loudly if absent.
if [ ! -f "src/chmp_inference/package.xml" ]; then
    echo "ERROR: src/chmp_inference/package.xml not found." >&2
    echo "       chmp_inference is bind-mounted from the host by docker-compose." >&2
    echo "       Ensure ~/code/chmp_inference exists on the host and the container" >&2
    echo "       was started via docker/run.sh, then retry." >&2
    exit 1
fi

# 3) Workspace venv WITH system site-packages so ROS2's rclpy stays importable.
if [ ! -f "$VENV/bin/activate" ]; then
    echo "==> Creating venv (--system-site-packages) at $VENV"
    python3 -m venv --system-site-packages "$VENV"
fi
# shellcheck disable=SC1091
source "$VENV/bin/activate"
python -m pip install --upgrade pip

# 4) Core lib + GPU stack, mirroring the validated RTX 5090 host recipe.
echo "==> Installing core lib (editable, [cuda] extra) from $CORE"
pip install -e "${CORE}[cuda]"
echo "==> Installing cu128 torch/torchvision (default PyPI wheel is cu130 and fails on sm_120)"
pip install --index-url https://download.pytorch.org/whl/cu128 torch torchvision

echo "==> Verifying JAX sees the GPU"
python -c "import jax; print('jax', jax.__version__, jax.devices())" \
    || echo "WARNING: jax could not enumerate the GPU. See README ptxas-fallback note."

# 5) RealSense (opt-in): only if the package was vcs-imported.
if [ -d "src/realsense_rgbd_streamer" ]; then
    echo "==> RealSense package present -> installing librealsense ROS2 driver"
    sudo apt-get update
    sudo apt-get install -y ros-jazzy-realsense2-camera ros-jazzy-librealsense2 \
        || echo "WARNING: librealsense apt install failed; see README RealSense notes."
fi

# 6) Build. colcon orders uq_msgs -> chmp_inference via the package.xml <depend>.
echo "==> colcon build --symlink-install"
colcon build --symlink-install

cat <<EOF

==> Setup complete.

Next steps (in a fresh shell, env is auto-sourced by the container bashrc):
    source /workspace/install/setup.bash
    ros2 launch chmp_inference pose_pipeline.launch.py model_root:=/opt/chmp/models

Rebuild after edits:  /workspace/scripts/build.sh
EOF
