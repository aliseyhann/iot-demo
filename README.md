# IoT Temperature Monitoring System

Contiki-NG native MQTT node + Mosquitto + Node.js WebSocket backend + dashboard.

## Architecture

```
[Contiki-NG Native Node] --MQTT--> [Mosquitto :1883] --MQTT--> [Node.js Backend :3000 WS] --> [Dashboard :8080]
```

## Services

- `mosquitto`: MQTT broker
- `contiki-sensor`: Custom Contiki-NG native MQTT client (`contiki_client/src/mqtt-client.c`)
- `backend`: MQTT subscriber + WebSocket broadcaster
- `dashboard`: static UI

## Run

```bash
docker compose --profile contiki up --build
```

Open: [http://localhost:8080](http://localhost:8080)

## Notes

- Python simulator has been removed from this project.
- `contiki-sensor` image is based on `contiker/contiki-ng`.
- Contiki source repo is cloned in image build if missing.
- Native binary is built at image build time (not container startup).
- Backend subscribes to `iot-2/evt/+/fmt/json`.
- Contiki payload includes:
  - `temperature`
  - `humidity`
  - `device_id` (`contiki-01`)
- Contiki publish interval is configured to 2 seconds.
- On Apple Silicon, first build can take longer due amd64 emulation.

## Quick Checks

```bash
# Contiki logs
docker compose logs -f contiki-sensor

# Backend should show Contiki messages
docker compose logs -f backend | grep "iot-2/evt/"
```
