# IoT Demo Run Instructions (VPS)

## 1) Ön Koşullar

- Docker ve Compose kurulu olmalı.
- `/dev/net/tun` mevcut olmalı.
- GCP/VPS firewall'da en az şu portlar açık olmalı:
  - `8080/tcp` (Dashboard)
  - `3000/tcp` (WebSocket)
  - `1883/tcp` (MQTT, dış erişim gerekmiyorsa şart değil)

## 2) Projeyi Güncelle

```bash
cd ~/iot-demo
git pull
```

## 3) Temiz Başlatma (Önerilen)

```bash
docker compose down
docker rm -f $(docker ps -aq --filter network=iot-demo_iot-net) 2>/dev/null || true
docker network rm iot-demo_iot-net 2>/dev/null || true

docker compose --profile contiki up --build -d
```

## 4) Hızlı Başlatma (Build almadan)

```bash
cd ~/iot-demo
docker compose --profile contiki up -d
```

## 5) Durum Kontrol

```bash
docker compose ps
docker compose logs --tail=120 contiki-sensor
docker compose logs --tail=80 mosquitto
docker compose logs --tail=80 backend
```

Beklenen kritik loglar:
- `contiki-sensor`: `MQTT Client Process`
- `mosquitto`: `d:quickstart:mqtt-client:...`
- `backend`: `[MQTT → WS] topic=iot-2/evt/status/fmt/json ...`
- `backend`: `[WebSocket] Yeni istemci bağlandı (toplam: 1)`

## 6) Dashboard Erişimi

```text
http://<VPS_PUBLIC_IP>:8080
```

VPS public IP öğrenmek için:

```bash
curl -s ifconfig.me
```

Not: Dashboard canlı veri için WebSocket `:3000` portuna bağlanır. Bu port dışarı açık olmalı.

## 7) Durdurma

Containerları silmeden durdur:

```bash
docker compose stop
```

Tekrar başlat:

```bash
docker compose start
```

Containerları kaldırarak kapat:

```bash
docker compose --profile contiki down
```

## 8) Sık Karşılaşılan Durumlar

### A) `Network ... Resource is still in use`

```bash
docker rm -f $(docker ps -aq --filter network=iot-demo_iot-net) 2>/dev/null || true
docker network rm iot-demo_iot-net
```

### B) İlk build çok uzun sürüyor

- İlk seferde `contiker/contiki-ng` image büyük olduğu için uzun sürmesi normaldir.
- Sonraki çalıştırmalarda cache nedeniyle ciddi şekilde kısalır.

### C) Dashboard'da `Waiting for data` / `Disconnected`

Kontrol et:
- `backend` logunda `[WebSocket] Yeni istemci bağlandı` var mı?
- `3000/tcp` firewall'da açık mı?
- Tarayıcıda hard refresh (`Ctrl+F5`) yaptın mı?
