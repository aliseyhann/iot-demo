#!/usr/bin/env bash
set -euo pipefail

CONTIKI_DIR="${CONTIKI_DIR:-/home/user/contiki-ng}"
APP_DIR="${CONTIKI_DIR}/examples/mqtt-client"
TUN_PREFIX="${TUN_PREFIX:-fd00:100::1/64}"
TUN_DEV="${TUN_DEV:-tun0}"
BROKER_PROXY_TARGET="${BROKER_PROXY_TARGET-mosquitto:1883}"
BROKER_IPV6="${BROKER_IPV6:-fd00:100::1}"

echo "[contiki] TUN prefix: ${TUN_PREFIX}"
echo "[contiki] TUN device: ${TUN_DEV}"
echo "[contiki] Broker proxy target: ${BROKER_PROXY_TARGET}"
echo "[contiki] MQTT broker IPv6: ${BROKER_IPV6}"

echo "[contiki] Network diagnostics before start"
ip -6 addr || true
ip -6 route || true

if [[ -n "${BROKER_PROXY_TARGET}" ]]; then
  echo "[contiki] Starting local MQTT TCP proxy on :1883 -> ${BROKER_PROXY_TARGET}"
  socat TCP6-LISTEN:1883,fork,reuseaddr TCP:${BROKER_PROXY_TARGET} &
else
  echo "[contiki] MQTT proxy disabled (direct IPv6 broker routing)"
fi

echo "[contiki] Building Contiki example mqtt-client"
sed -i "s|^#define MQTT_CLIENT_CONF_BROKER_IP_ADDR \".*\"|#define MQTT_CLIENT_CONF_BROKER_IP_ADDR \"${BROKER_IPV6}\"|" \
  "${APP_DIR}/project-conf.h"
CCACHE_DISABLE=1 make -C "${APP_DIR}" TARGET=native clean all

echo "[contiki] Starting mqtt-client.native"
exec "${APP_DIR}/build/native/mqtt-client.native" --prefix "${TUN_PREFIX}" -t "${TUN_DEV}"
