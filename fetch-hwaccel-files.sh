#!/bin/bash
# Fetch Immich's upstream hardware-acceleration compose fragments.
#
# You usually do NOT need these: 2a_MyUnraid_docker-compose.yml already INLINES
# the NVIDIA settings, so there is nothing to `extends:` from. Keep this only if
# you'd rather use upstream's `extends:` approach with hwaccel.*.yml instead.
#
# Run it from your Compose Manager project directory.

cd /mnt/user/appdata/immich && ls   # verify docker-compose.yml is present first
wget https://raw.githubusercontent.com/immich-app/immich/refs/heads/main/docker/hwaccel.ml.yml
wget https://raw.githubusercontent.com/immich-app/immich/refs/heads/main/docker/hwaccel.transcoding.yml
