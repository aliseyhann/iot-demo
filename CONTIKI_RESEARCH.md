# Contiki-NG MQTT Integration Notes

## Current State (2026-02-27)

Integration is complete and running with Contiki-NG as the only publisher.

### Implemented

- `contiki_client/` added:
  - `Dockerfile`
  - `run-contiki.sh`
  - `project-conf.h.template`
- `docker-compose.yml` updated:
  - `contiki-sensor` profile/service enabled
  - IPv6-enabled bridge network (`fd00:10::/64`)
  - `/dev/net/tun` + `NET_ADMIN`
- `backend/server.js` updated:
  - subscribes to `iot-2/evt/+/fmt/json`
  - normalizes Contiki payload for dashboard
- `dashboard/index.html` updated to reflect Contiki-only flow

### Runtime Strategy

- Contiki source is cloned from:
  - `https://github.com/contiki-ng/contiki-ng`
- `examples/mqtt-client` is built with `TARGET=native`.
- `run-contiki.sh` applies runtime source tweaks before build:
  - native connectivity fix for Docker
  - payload fields: `temperature`, `humidity`, `device_id`
  - publish interval: 2 seconds
- Local MQTT proxy in contiki container:
  - listens on `fd00:100::1:1883`
  - forwards to `mosquitto:1883`

### Verified Behavior

- Contiki connects to Mosquitto with client id:
  - `d:quickstart:mqtt-client:010203060708`
- Backend logs include messages on:
  - `iot-2/evt/status/fmt/json`
- Payload reaches dashboard with non-null `temperature`/`humidity`.

## Run

```bash
docker compose --profile contiki up --build
```
