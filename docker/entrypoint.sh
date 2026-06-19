#!/bin/bash
set -e

# Get user information from environment variables
USER_ID=${LOCAL_USER_ID:-1000}
GROUP_ID=${LOCAL_GROUP_ID:-1000}
USERNAME=${LOCAL_USERNAME:-user}

# Create group if it doesn't exist
if ! getent group $GROUP_ID > /dev/null 2>&1; then
    groupadd -g $GROUP_ID $USERNAME
fi

# Create user if it doesn't exist
if ! id -u $USERNAME > /dev/null 2>&1; then
    useradd -m -u $USER_ID -g $GROUP_ID -s /bin/bash $USERNAME

    # Passwordless sudo + GPU (video) group
    usermod -aG sudo $USERNAME
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    usermod -aG video $USERNAME
fi

USER_HOME="/home/$USERNAME"

# Create bashrc if it doesn't exist
if [ ! -f "$USER_HOME/.bashrc" ]; then
    cp /etc/skel/.bashrc "$USER_HOME/.bashrc"
fi

# Source order matters: ROS2 -> workspace venv -> colcon overlay.
# Activating the venv (created with --system-site-packages) after ROS2 keeps rclpy
# visible while putting the editable core lib + jax/torch on the path first.
if ! grep -q "# chmp_workspace env setup" "$USER_HOME/.bashrc"; then
    cat >> "$USER_HOME/.bashrc" <<'EOF'

# chmp_workspace env setup
# 1) ROS2 Jazzy
source /opt/ros/jazzy/setup.bash
# 2) Workspace Python venv (created by scripts/setup_workspace.sh)
if [ -f /workspace/.venv/bin/activate ]; then
    source /workspace/.venv/bin/activate
fi
# 3) colcon overlay (uq_msgs, chmp_inference, ...)
if [ -f /workspace/install/setup.bash ]; then
    source /workspace/install/setup.bash
fi
EOF
fi

# Fix ownership of home directory
chown -R $USER_ID:$GROUP_ID "$USER_HOME"

# Idempotent editable relink of the core lib: keeps /opt/chmp linked into the venv
# across `docker compose` recreations. Deps are already present, so --no-deps is
# fast. Guarded on venv existence so the first boot (before setup_workspace.sh) is
# a no-op rather than an error.
if [ -f /workspace/.venv/bin/activate ] && [ -f /opt/chmp/pyproject.toml ]; then
    echo "[entrypoint] Relinking editable core lib (/opt/chmp) into venv..."
    gosu $USERNAME bash -lc "source /workspace/.venv/bin/activate && pip install -e /opt/chmp --no-deps -q" \
        || echo "[entrypoint] WARNING: editable relink failed; run scripts/setup_workspace.sh."
fi

# Export environment variables for the user
export HOME="$USER_HOME"

# Execute command as the specified user
exec gosu $USERNAME "$@"
