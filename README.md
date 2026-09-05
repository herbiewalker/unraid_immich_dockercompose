# Immich on Unraid — docker-compose stack

Docker Compose files for my [Immich](https://immich.app) (self-hosted photo/video
library) stack on Unraid.
This is a **live, in-use install** — the photo library and database must be preserved.

> **TL;DR:** deploy `compose/immich.gpu.yml`, copy `env/immich.env.example`
> to `.env` and set a real `DB_PASSWORD`. Everything else is reference or fallback.

## The stack at a glance

Four containers on one internal bridge network (`immich-net`). Only the web UI
port is published to the host:

| Service | Container | Role |
|---------|-----------|------|
| `immich-server` | `immich_server` | Web UI + API. Published on host port **2283**. |
| `immich-machine-learning` | `immich_machine_learning` | Smart search, face/object detection. Uses the CUDA image on GPU. |
| `redis` (valkey) | `immich_redis` | Ephemeral job-queue cache. No published port; data is throwaway. |
| `database` (postgres) | `immich_postgres` | Postgres 18 + VectorChord — photo metadata and search vectors. **The important state.** |

## Repo layout

```
compose/
  immich.gpu.yml        Canonical / finalized compose — GPU (NVENC transcode + CUDA ML). Deploy this.
  immich.cpu.yml        CPU-only variant (no GPU). Fallback for when the driver is unavailable.
env/
  immich.env.example    Copy to .env — TZ, pinned version, DB connection. Set a real DB_PASSWORD.
scripts/
  pre-create-folders.sh Creates the Unraid share folders the stack bind-mounts. Run once on a fresh host.
  fetch-hwaccel-files.sh Pulls upstream hwaccel.*.yml (only if you prefer `extends:` — already inlined into gpu).
reference/
  upstream-docker-compose.yml  Immich's official compose, unmodified. For diffing only — do not deploy.
  upstream.env.example         Immich's official example .env, unmodified.
```

> Local-only, never committed (see `.gitignore`): the real `.env`, `*-diagnostics-*.zip`
> Unraid diagnostics snapshots, and `*.sql` DB dumps.

## Live stack (verified 2026-09-05, all healthy)

- **Immich:** v2.7.5 (server + machine-learning; ML uses the `-cuda` image with `runtime: nvidia`). CUDAExecutionProvider confirmed active in ML logs; GPU load observed during Smart Search / Facial Recognition jobs.
- **Postgres:** already **PG18** — `postgres:18-vectorchord0.5.3`, data at `/var/lib/postgresql/18/docker`, VectorChord 0.5.3 + pgvector 0.8.1. No pg14→pg18 migration is pending.
- **Redis:** `valkey:8-bookworm`.
- **GPU:** NVIDIA RTX 3060 Ti (driver 595.84 / CUDA 13.2), `nvidia-driver` plugin. GPU services need **`runtime: nvidia`** + the `deploy.reservations.devices` block.

> **First-boot gotcha (ML `-cuda` image):** after switching ML to `-cuda`, the container may come up `unhealthy` and refuse all connections (including its own `localhost:3003/ping`) for many minutes on first launch, with only gunicorn boot lines in the logs. A plain `docker restart immich_machine_learning` clears it — models then load and the CUDA provider initialises normally. If it recurs after an image bump, restart before rebuilding.

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
2. Copy `compose/immich.gpu.yml` → project `docker-compose.yml`, and `env/immich.env.example` → project `.env` (fill in the real `DB_PASSWORD`).
3. *(Optional)* pin the postgres digest: `docker inspect immich_postgres --format '{{index .RepoDigests 0}}'` and append `@sha256:...` to the image tag.
4. Redeploy (Down → Up / Update Stack). Confirm all four containers are `healthy` via `docker ps`.

### Pre-create the share folders (fresh host only)
Run `scripts/pre-create-folders.sh`, or the equivalent by hand:
```bash
mkdir -p /mnt/user/appdata_immich/immich/{config,database/postgres,database/redis}
mkdir -p /mnt/user/immich/immich/photos
```

## Hardening to-do
- Set `DB_PASSWORD` to a strong, unique value — on an existing DB this is `ALTER USER ... WITH PASSWORD` **plus** the env var, in lockstep (see `env/immich.env.example`).
- Immich has no built-in auth gate; consider binding port `2283` to a single trusted interface (LAN or VPN) instead of all (`<IP>:2283:2283`).
- `IMMICH_VERSION` is pinned to `v2.7.5` — bump deliberately after reading release notes + a DB backup.

## References
- Immich Unraid install: https://docs.immich.app/install/unraid
- Immich upgrading guide: https://docs.immich.app/install/upgrading/
- Compose-file guide used as a starting point: https://bmartino1.weebly.com/immich-on-unraid-docker-compose-guide.html
- Unraid forum Q/A thread: https://forums.unraid.net/topic/193998-guide-immich-docker-setup-docker-compose/#comment-1582198

## License

MIT — see [`LICENSE`](LICENSE).
