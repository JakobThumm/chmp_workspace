# chmp_workspace

Runnable **ROS2 Jazzy workspace** for real-time human pose estimation + motion
prediction with uncertainty quantification, on an RTX 5090 (Blackwell / sm_120).

This is the **meta-repo** of a three-repo split:

| Repo | Role |
|------|------|
| [`conformal_human_motion_prediction`](https://github.com/JakobThumm/conformal_human_motion_prediction) | Core Python/JAX methodology (ROS2-free). Installed into the workspace venv as an **editable** package — *not* a colcon package. |
| [`chmp_inference`](https://github.com/JakobThumm/chmp_inference) | ROS2 `ament_python` node package (pose pipeline, motion prediction). Dev-mounted into `src/`. |
| **`chmp_workspace`** (this repo) | Docker + scripts + a `.repos` manifest that assemble the runnable colcon workspace. |

After setup the workspace looks like:

```
chmp_workspace/
└─ src/
     ├─ chmp_inference            # dev-mounted from host ~/code/chmp_inference
     ├─ uq_msgs                   # vcs-imported, pinned (chmp_workspace.repos)
     └─ realsense_rgbd_streamer   # vcs-imported — OPT-IN only
```

The core lib `conformal_human_motion_prediction` is **not** in `src/`; it is
`pip install -e`'d into the workspace venv from the `/opt/chmp` dev mount.

## Prerequisites

- **nvidia-docker** (NVIDIA Container Toolkit) and Docker Compose v2 (`docker compose`).
- Host GPU: **RTX 5090** (or another sm_120 / Blackwell card), driver providing **CUDA ≥ 12.8**.
- Host clones laid out as **siblings** (the compose mounts assume this):
  ```
  ~/code/conformal_human_motion_prediction
  ~/code/chmp_inference
  ~/code/chmp_workspace        # this repo
  ```
- Model artifacts present under the core repo (`conformal_human_motion_prediction/models/`).
  Fetch them on the host with the core repo's `python scripts/download_models.py`.

## Quickstart

```bash
cd chmp_workspace/docker
./build.sh          # build the CUDA 12.8 + ROS2 Jazzy image (system layer only)
./run.sh            # start the container (detached; runs the Zenoh router)
./shell.sh          # open an interactive shell

# --- inside the container, one time ---
/workspace/scripts/setup_workspace.sh

# --- launch the pipeline ---
source /workspace/install/setup.bash
ros2 launch chmp_inference pose_pipeline.launch.py model_root:=/opt/chmp/models
```

The node then publishes on `/uq/pose_2d`, `/uq/pose_3d`, and `/uq/motion_prediction`.
`model_root:=/opt/chmp/models` points the relative model paths in the launch file at
the mounted core repo's `models/` dir. Enable OOD with `enable_ood:=true`.

## Dev-mount workflow — what is live vs. needs a rebuild

The container bind-mounts the three host repos, so edits on the host take effect inside:

| You edited | To apply |
|------------|----------|
| Core lib (`conformal_human_motion_prediction/**`) | Live — it's an editable install. Just restart the node. |
| `chmp_inference` node `*.py` | Live after `source /workspace/install/setup.bash` (`--symlink-install`). |
| `chmp_inference` `setup.py` / `package.xml` / entry points, or `uq_msgs` `.msg` | `/workspace/scripts/build.sh`, then re-source. |
| Dockerfile / system / CUDA / ROS2 packages | `docker/build.sh` (image rebuild). |

The entrypoint re-links the editable core install (`pip install -e /opt/chmp --no-deps`)
on every container start, so the mount stays linked across `docker compose` recreations.

## RealSense (opt-in)

RealSense hardware streaming is **off by default**. To enable it:

1. Uncomment the `realsense_rgbd_streamer` block in [`chmp_workspace.repos`](chmp_workspace.repos).
2. Re-run `/workspace/scripts/setup_workspace.sh`. It will `vcs import` the package and,
   detecting it in `src/`, `apt-get install` the librealsense ROS2 driver
   (`ros-jazzy-realsense2-camera`) before building.

Without it, the pipeline consumes a compressed RGB-D stream on the
`rgbd_stream/{rgb,depth}/compressed` topics (publish from any source).

## GPU / ptxas notes

The image's CUDA 12.8 devel base ships a recent `ptxas`, so JAX assembles sm_120
kernels natively — the host repo's `_cuda_ptxas_shim` is **not** needed here.

If JAX still aborts with `PTX version ... does not support target 'sm_120a'`, the
in-container `ptxas` is too old for the installed jaxlib. Prepend a newer one to PATH,
e.g. from the jax CUDA wheels:

```bash
python -c "import nvidia.cuda_nvcc; print(nvidia.cuda_nvcc.__path__[0])"
# add the bin/ under that path (containing ptxas) to the front of PATH
```

The GPU is often shared, so `XLA_PYTHON_CLIENT_PREALLOCATE=false` is set in the image
to avoid JAX's 75% pre-allocation OOM.

## Layout

```
chmp_workspace/
├── chmp_workspace.repos     # vcstool manifest (uq_msgs pinned; realsense commented)
├── docker/
│   ├── Dockerfile           # CUDA 12.8 devel + ROS2 Jazzy + colcon + vcstool
│   ├── docker-compose.yml   # GPU, dev mounts, zenoh, host net/ipc
│   ├── entrypoint.sh        # UID/GID match + bashrc env + editable relink
│   ├── build.sh run.sh shell.sh stop.sh
│   └── router.json5
├── scripts/
│   ├── setup_workspace.sh   # one-time: vcs import -> venv -> pip install core -> colcon build
│   └── build.sh             # colcon rebuild helper
└── src/                     # populated at setup (gitignored except .gitkeep)
```
