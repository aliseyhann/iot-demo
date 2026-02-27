#!/usr/bin/env bash
set -euo pipefail

CONTIKI_DIR="${CONTIKI_DIR:-/opt/contiki-ng}"
EXAMPLE_DIR="${CONTIKI_DIR}/examples/mqtt-client"
BROKER_IPV6="${BROKER_IPV6:-fd00:100::1}"
TUN_PREFIX="${TUN_PREFIX:-fd00:100::1/64}"
TUN_DEV="${TUN_DEV:-tun0}"
BROKER_PROXY_TARGET="${BROKER_PROXY_TARGET:-mosquitto:1883}"

echo "[contiki] MQTT broker IPv6: ${BROKER_IPV6}"
echo "[contiki] TUN prefix: ${TUN_PREFIX}"
echo "[contiki] TUN device: ${TUN_DEV}"
echo "[contiki] Broker proxy target: ${BROKER_PROXY_TARGET}"
MQTT_CLIENT_C="${EXAMPLE_DIR}/mqtt-client.c"
echo "[contiki] Applying native connectivity fix"
if ! grep -q 'strncmp(CONTIKI_TARGET_STRING, "native", 6)' "${MQTT_CLIENT_C}"; then
  perl -0777 -i -pe 's@static bool\s+have_connectivity\(void\)\s*\{\s*if\(uip_ds6_get_global\(ADDR_PREFERRED\) == NULL \|\|\s*uip_ds6_defrt_choose\(\) == NULL\)\s*\{\s*return false;\s*\}\s*return true;\s*\}@static bool\nhave_connectivity(void)\n{\n  if(uip_ds6_get_global(ADDR_PREFERRED) == NULL) {\n    return false;\n  }\n\n  /* Native target in Docker may not create a RPL default route object. */\n  if(strncmp(CONTIKI_TARGET_STRING, "native", 6) == 0) {\n    return true;\n  }\n\n  if(uip_ds6_defrt_choose() == NULL) {\n    return false;\n  }\n\n  return true;\n}@s' "${MQTT_CLIENT_C}"
else
  echo "[contiki] Connectivity fix already present"
fi

echo "[contiki] Applying payload format fix (temperature/humidity/device_id)"
if ! grep -q 'device_id\\":\\"contiki-01' "${MQTT_CLIENT_C}"; then
  perl -0777 -i -pe 's/int i;\n  char def_rt_str\[64\];/int i;\n  int temperature;\n  int humidity;\n  char def_rt_str[64];/s' "${MQTT_CLIENT_C}"
  perl -0777 -i -pe 's/seq_nr_value\+\+;/seq_nr_value++;\n\n  temperature = 20 + (seq_nr_value % 16);\n  humidity = 40 + ((seq_nr_value * 3) % 51);/s' "${MQTT_CLIENT_C}"
  perl -0777 -i -pe 's/len = snprintf\(buf_ptr, remaining, "\}\}"\);/len = snprintf(buf_ptr, remaining,\n                 ",\\"temperature\\":%d,\\"humidity\\":%d,\\"device_id\\":\\"contiki-01\\"}}",\n                 temperature, humidity);/s' "${MQTT_CLIENT_C}"
else
  echo "[contiki] Payload format fix already present"
fi

echo "[contiki] Setting publish interval to 2 seconds"
perl -0777 -i -pe 's/#define DEFAULT_PUBLISH_INTERVAL\s+\(30 \* CLOCK_SECOND\)/#define DEFAULT_PUBLISH_INTERVAL    (2 * CLOCK_SECOND)/s' "${MQTT_CLIENT_C}"

echo "[contiki] Preparing project-conf.h"
sed "s|__BROKER_IPV6__|${BROKER_IPV6}|g" \
  /contiki_client/project-conf.h.template \
  > "${EXAMPLE_DIR}/project-conf.h"

echo "[contiki] Building native mqtt-client"
make -C "${EXAMPLE_DIR}" TARGET=native clean all

echo "[contiki] Network diagnostics before start"
ip -6 addr || true
ip -6 route || true

echo "[contiki] Starting local MQTT TCP proxy on :1883 -> ${BROKER_PROXY_TARGET}"
socat TCP6-LISTEN:1883,fork,reuseaddr TCP:${BROKER_PROXY_TARGET} &

echo "[contiki] Starting mqtt-client.native"
exec "${EXAMPLE_DIR}/build/native/mqtt-client.native" --prefix "${TUN_PREFIX}" -t "${TUN_DEV}"
