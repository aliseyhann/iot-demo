# Contiki-NG MQTT Integration Notes

## Current State (2026-02-27)

Integration is complete and running with Contiki-NG as the only publisher.

### Implemented

- `contiki_client/` added:
  - `Dockerfile`
  - `run-contiki.sh`
  - `src/mqtt-client.c` (custom client)
  - `src/Makefile`
  - `src/project-conf.h`
- `docker-compose.yml` updated:
  - `contiki-sensor` profile/service enabled
  - IPv6-enabled bridge network (`fd00:10::/64`)
  - `/dev/net/tun` + `NET_ADMIN`
- `backend/server.js` updated:
  - subscribes to `iot-2/evt/+/fmt/json`
  - normalizes Contiki payload for dashboard
- `dashboard/index.html` updated to reflect Contiki-only flow

### Runtime Strategy

- Base image:
  - `contiker/contiki-ng:latest`
- If Contiki source is missing in image, Dockerfile clones:
  - `https://github.com/contiki-ng/contiki-ng`
- Custom app (`contiki_client/src/mqtt-client.c`) is built with `TARGET=native`
  during image build.
- Runtime patching is removed; behavior is versioned in project source.
- Local MQTT proxy in contiki container:
  - listens on `fd00:100::1:1883`
  - forwards to `mosquitto:1883`

### Known Constraint

- On Apple Silicon, `contiker/contiki-ng` runs as amd64 emulation.
  First image build can be slower.

## Run

```bash
docker compose --profile contiki up --build
```
