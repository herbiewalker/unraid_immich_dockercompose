#!/bin/bash
# Pre-create the Unraid share folders that the Immich stack bind-mounts.
#
# Run this ONCE on a fresh host, BEFORE the first `docker compose up`, so the
# bind mounts in the compose file point at directories that already exist.
# (Docker would otherwise create them as root-owned and, on Unraid, outside
# your intended share/pool.)

# Config + databases live on the SSD cache pool:
mkdir -p /mnt/user/appdata_immich/immich/{config,database/postgres,database/redis,photos}

# If you store the photo library on the ZFS pool instead (as 2a's immich-photos
# volume does), create that path too — and drop `photos` from the line above.
mkdir -p /mnt/user/immich/immich/photos
