# IoT Temperature Monitoring System

Contiki-NG native MQTT node + Mosquitto + Node.js WebSocket backend + dashboard.

## Architecture

```
[Contiki-NG Native Node] --MQTT--> [Mosquitto :1883] --MQTT--> [Node.js Backend :3000 WS] --> [Dashboard :8080]
```

## Services

- `mosquitto`: MQTT broker
- `contiki-sensor`: Contiki-NG native `examples/mqtt-client` (Dockerized)
- `backend`: MQTT subscriber + WebSocket broadcaster
- `dashboard`: static UI

## Run

```bash
docker compose --profile contiki up --build
```

Open: [http://localhost:8080](http://localhost:8080)

## Notes

- Python simulator has been removed from this project.
- Backend subscribes to `iot-2/evt/+/fmt/json`.
- Contiki payload includes:
  - `temperature`
  - `humidity`
  - `device_id` (`contiki-01`)
- Contiki publish interval is configured to 2 seconds.

## Quick Checks

```bash
# Contiki logs
docker compose logs -f contiki-sensor

# Backend should show Contiki messages
docker compose logs -f backend | grep "iot-2/evt/"
```
