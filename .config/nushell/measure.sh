#!/usr/bin/env bash
set -euo pipefail

CG="/sys/fs/cgroup/measure"
sudo mkdir -p "$CG"

# Enable memory controller on the root (if not yet)
echo "+memory" | sudo tee /sys/fs/cgroup/cgroup.subtree_control >/dev/null

# Ensure no limit
echo max | sudo tee "$CG/memory.max" >/dev/null

# Place *this shell* inside, before it forks
echo $$ | sudo tee "$CG/cgroup.procs" >/dev/null

# Now every child (and grandchild) stays inside
exec "$@"
