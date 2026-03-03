# Contiker/Contiki-NG + Kendi MQTT Client Planı (Linux)

## 1. Amaç

Bu planın hedefi:

- `contiker/contiki-ng` image’ını kullanmak
- Kendi C tabanlı Contiki MQTT client’ını proje içinde versiyonlamak
- Sistemi Linux host üzerinde stabil şekilde çalıştırmak
- Önceden yaşanan hataları (TUN, tool eksikleri, patch kırılması, connect loop, mimari uyumsuzluk) tekrar etmemek

---

## 2. Başarı Kriterleri (Definition of Done)

- `docker compose --profile contiki up --build` hatasız tamamlanır.
- `contiki-sensor` container crash olmadan çalışır.
- Mosquitto logunda Contiki client bağlantısı görünür.
- Backend logunda `iot-2/evt/status/fmt/json` mesajları düzenli akar.
- Backend normalize edilmiş payload’da `temperature`, `humidity`, `device_id` alanlarını gönderir.
- Dashboard sadece Contiki akışını gösterir.

---

## 3. Linux Ortam Ön Koşulları

## 3.1 Host Gereksinimleri

- Linux kernel (öneri: Ubuntu 22.04/24.04 veya Debian 12)
- Docker Engine + Docker Compose plugin
- `/dev/net/tun` mevcut olmalı
- IPv6 bridge networking aktif olmalı

Kontrol komutları:

```bash
docker --version
docker compose version
ls -l /dev/net/tun
sysctl net.ipv6.conf.all.disable_ipv6
```

Beklenen:

- `/dev/net/tun` cihaz dosyası mevcut
- `net.ipv6.conf.all.disable_ipv6 = 0`

## 3.2 Host Stabilite Ayarları

- Gerekirse:

```bash
sudo modprobe tun
```

- Docker daemon’da IPv6 gerekirse etkinleştirilmeli (`/etc/docker/daemon.json`).

---

## 4. Hedef Mimari

- `mosquitto`: MQTT broker
- `contiki-sensor`: `contiker/contiki-ng` tabanlı container
- `backend`: MQTT subscriber + WS bridge
- `dashboard`: frontend

Contiki akışı:

1. Container açılır
2. TUN cihazı hazırlanır (`--prefix fd00:100::1/64 -t tun0`)
3. Kendi `mqtt-client.native` binary’si çalışır
4. Mesajları `iot-2/evt/status/fmt/json` topic’ine yayınlar
5. Backend normalize ederek dashboard’a iletir

---

## 5. Kodlama Stratejisi

## 5.1 Kendi Client’ı Versiyonla

Proje içinde kalıcı kaynaklar:

- `contiki_client/src/mqtt-client.c`
- `contiki_client/src/Makefile`
- `contiki_client/src/project-conf.h`

Not:
- Runtime patch yerine doğrudan kendi kaynak kodunu derlemek tercih edilir.
- Patch dosyası sadece geçiş için kullanılmalı.

## 5.2 Build Stratejisi

İki seçenek:

1. **Image build sırasında derleme** (önerilen)
   - Daha deterministik
   - Runtime’da daha az hata olasılığı
2. Runtime’da derleme
   - Daha yavaş
   - Geçici ağ/repo sorunlarına açık

Öneri: Build-time compile.

## 5.3 MQTT Tasarım Kararları

- Topic: `iot-2/evt/status/fmt/json`
- QoS: 0 (başlangıç için)
- Publish interval: 2 sn
- Payload:

```json
{
  "d": {
    "temperature": 24,
    "humidity": 51,
    "device_id": "contiki-01",
    "seq": 42
  }
}
```

---

## 6. Docker/Compose Uygulama Planı

## 6.1 `contiki_client/Dockerfile`

- Base: `contiker/contiki-ng:latest`
- Gerekli paketler:
  - `git`, `make`, `build-essential`, `iproute2`, `iputils-ping`, `net-tools`, `socat`, `procps`
- Contiki source doğrulaması:
  - Eğer `/home/user/contiki-ng/Makefile.include` yoksa clone et
- Kendi `src/` klasörünü kopyala
- `make TARGET=native` ile binary derle

## 6.2 `docker-compose.yml`

`contiki-sensor` için:

- `cap_add: [NET_ADMIN]`
- `devices: [/dev/net/tun:/dev/net/tun]`
- IPv6 network (`fd00:10::/64`)
- Ortam değişkenleri:
  - `TUN_PREFIX=fd00:100::1/64`
  - `TUN_DEV=tun0`
  - `BROKER_IPV6=fd00:100::1` (proxy modunda)
  - `BROKER_PROXY_TARGET=mosquitto:1883` (proxy kullanılacaksa)

---

## 7. Geçmiş Hatalar ve Önleme Matrisi

## 7.1 `ifconfig/netstat: not found`

Neden:
- Contiki native runtime bu araçları çağırıyor.

Önlem:
- `net-tools` paketini image’a ekle.

## 7.2 `Input/output error` / TUN sorunları

Neden:
- `/dev/net/tun` eksikliği, yetki eksikliği veya yanlış cap/device ayarı.

Önlem:
- `NET_ADMIN` + `/dev/net/tun` mount
- Container içinde `ip -6 addr`, `ip -6 route` ile startup diagnostik.

## 7.3 Sürekli `mqtt_connect` loop / protocol error

Neden:
- Aynı anda birden çok connect denemesi veya bozuk state yönetimi.

Önlem:
- Tekil state machine:
  - `NOT_CONNECTED -> CONNECTING -> CONNECTED`
- Stall timeout + kontrollü reconnect.

## 7.4 Patch kırılması (`malformed patch`)

Neden:
- Upstream dosya değişimi sonrası satır uyuşmazlığı.

Önlem:
- Runtime patch kullanımını kaldır.
- Kendi C dosyanı repo’da tut.

## 7.5 Mimari uyumsuzluğu (özellikle Apple Silicon)

Neden:
- amd64 image emülasyonu.

Önlem:
- Nihai doğrulamayı native Linux cihazda yap.
- Gerekirse `platform` sabitlemesi ve host mimarisi uyumu.

---

## 8. Uygulama Aşamaları (Milestones)

## Aşama 1: Temiz Başlangıç

```bash
docker compose down -v
docker system prune -f
```

## Aşama 2: Build Doğrulama

```bash
docker compose --profile contiki build --no-cache contiki-sensor
```

Başarılıysa binary build artifact’i doğrula.

## Aşama 3: Runtime Doğrulama

```bash
docker compose --profile contiki up
```

Kontroller:

- `contiki-sensor` crash yok
- mosquitto’da Contiki client bağlantısı var
- backend’de topic akışı var

## Aşama 4: Payload Uyum Doğrulama

Backend logunda:

- `temperature` dolu
- `humidity` dolu
- `device_id` dolu

## Aşama 5: Stabilite Testi

- En az 10-15 dakika kesintisiz çalıştır
- Container restart test et:

```bash
docker compose restart contiki-sensor
```

---

## 9. Test Planı

## 9.1 Fonksiyonel Testler

- Broker bağlantısı
- Publish interval (2 sn)
- Dashboard canlı güncelleme

## 9.2 Negatif Testler

- Mosquitto restart:
  - client reconnect ediyor mu?
- Contiki container restart:
  - otomatik toparlıyor mu?

## 9.3 Gözlem Komutları

```bash
docker compose logs -f contiki-sensor
docker compose logs -f mosquitto
docker compose logs -f backend
```

---

## 10. Rollback Planı

Eğer `contiker/contiki-ng` tabanında Linux’ta da kritik stabilite sorunu sürerse:

1. Base image’i geçici olarak `ubuntu:24.04` yap
2. Aynı Contiki source + aynı custom C client ile devam et
3. Fonksiyonel teslimi koru
4. Sonra `contiker` için ayrı hardening branch’i aç

---

## 11. Branch ve Commit Stratejisi

- Branch adı: `codex/contiker-custom-client-linux`
- Küçük commitler:
  - Docker hardening
  - Custom C client
  - Compose network/cap fixes
  - Backend normalization
  - Docs/tests

Önerilen commit mesajı formatı:

- `feat(contiki): run custom native mqtt client on contiker image with stable tun/ipv6 setup`

---

## 12. Beklenen Sonuç

Linux cihazda bu plan uygulandığında:

- `contiker/contiki-ng` image üzerinde kendi client’ın çalışır
- Contiki -> Mosquitto -> Backend -> Dashboard zinciri stabil olur
- Geçmişteki entegrasyon hataları sistematik olarak engellenir

