# Immich on server-b (Unraid) — docker-compose stack

Docker Compose files for my Immich stack on the **server-b** Unraid server.
This is a **live, in-use install** — the photo library and database must be preserved.

## Files in this repo

| File | Purpose |
|------|---------|
| `2a_MyUnraid_docker-compose.yml` | **Canonical / finalized** compose — GPU (NVENC transcode + CUDA ML). Deploy this. |
| `2_MyUnraid_docker-compose.yml` | CPU-only variant (no GPU). Fallback. |
| `1_ImmichSiteOG_docker-compose.yml` | Upstream reference compose (unmodified). Do not deploy as-is. |
| `4_MyUnraid_example.env` | Example `.env` (TZ, pinned version, DB connection). |
| `3_ImmichSiteOG_Example.env` | Upstream reference `.env`. |
| `Pre-create Unraid folders.txt` | `mkdir` commands to pre-create the share folders. |
| `Fetch hwaccel compose files.txt` | How to pull upstream `hwaccel.*.yml` (settings are inlined into `2a`, so not required). |
| `server-b-diagnostics-*.zip` | Unraid diagnostics snapshot for reference. |

## Live stack (verified 2026-06-02, all healthy)

- **Immich:** v2.7.5 (server + machine-learning; ML uses the `-cuda` image).
- **Postgres:** already **PG18** — `postgres:18-vectorchord0.5.3`, data at `/var/lib/postgresql/18/docker`, VectorChord 0.5.3 + pgvector 0.8.1. No pg14→pg18 migration is pending.
- **Redis:** `valkey:8-bookworm`.
- **GPU:** NVIDIA RTX 3060 Ti (driver 595.71.05 / CUDA 13.2), `nvidia-driver` plugin. GPU services need **`runtime: nvidia`** + the `deploy.reservations.devices` block.

## Storage layout (non-standard — read before changing paths)

| Data | Host path | Pool |
|------|-----------|------|
| Photo library (~425 GB) | `/mnt/user/immich/immich/photos` → container `/usr/src/app/upload` | `immich` share: SSD `cache_immich` → mover → ZFS raidz1 `pool_zfs` (nightly 02:15) |
| Postgres DB | `/mnt/user/appdata_immich/immich/database/postgres` | `cache_immich` SSD (cache-only) |
| Redis | `/mnt/user/appdata_immich/immich/database/redis` | `cache_immich` SSD |
| ML model cache | `/mnt/user/appdata_immich/immich/config` | `cache_immich` SSD |

> `IMMICH_MEDIA_LOCATION` / `UPLOAD_LOCATION` are intentionally **unset** — v2.7.5 defaults media to `/usr/src/app/upload`, which is where the existing library lives. The container's `/data` volume is empty and unused (do not "fix" it).

## Deploy / update runbook

Stack is deployed via the Unraid **Compose Manager** plugin (project dir
`/boot/config/plugins/compose.manager/projects/immich/`).

1. **Back up the database first, every time:**
   ```bash
   docker exec -t immich_postgres pg_dumpall --clean --if-exists -U postgres \
     > /mnt/user/appdata_immich/immich/immich-db-$(date +%F).sql
   ```
2. Copy `2a_MyUnraid_docker-compose.yml` → project `docker-compose.yml`, and `4_MyUnraid_example.env` → project `.env` (fill in the real `DB_PASSWORD`).
3. *(Optional)* pin the postgres digest: `docker inspect immich_postgres --format '{{index .RepoDigests 0}}'` and append `@sha256:...` to the image tag.
4. Redeploy (Down → Up / Update Stack). Confirm all four containers are `healthy` via `docker ps`.

### Pre-create the share folders (fresh host only)
```bash
mkdir -p /mnt/user/appdata_immich/immich/{config,database/postgres,database/redis}
mkdir -p /mnt/user/immich/immich/photos
```

## Hardening to-do
- Rotate `DB_PASSWORD` off the default `postgres` — on an existing DB this is `ALTER USER ... WITH PASSWORD` **plus** the env var, in lockstep (see `4_MyUnraid_example.env`).
- Consider binding port `2283` to a single interface instead of all (`<IP>:2283:2283`).
- `IMMICH_VERSION` is pinned to `v2.7.5` — bump deliberately after reading release notes + a DB backup.

## References
- Immich Unraid install: https://docs.immich.app/install/unraid
- Immich upgrading guide: https://docs.immich.app/install/upgrading/
- Compose-file guide used as a starting point: https://bmartino1.weebly.com/immich-on-unraid-docker-compose-guide.html
- Unraid forum Q/A thread: https://forums.unraid.net/topic/193998-guide-immich-docker-setup-docker-compose/#comment-1582198
