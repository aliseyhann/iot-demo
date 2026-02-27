/**
 * IoT Backend Server — MQTT Subscriber + WebSocket Server
 * IoT Backend Sunucusu — MQTT Abone + WebSocket Sunucusu
 *
 * This server is the BRIDGE between the two protocols:
 *
 * 1. MQTT Side (Subscriber):
 *    - Connects to Mosquitto broker on localhost:1883
 *    - Subscribes to "iot-2/evt/+/fmt/json" (Contiki default)
 *    - Normalizes messages to one dashboard payload format
 *
 * 2. WebSocket Side (Server):
 *    - Runs a WebSocket server on port 3000
 *    - Maintains persistent, full-duplex connections with browser clients
 *    - When an MQTT message arrives, broadcasts it to ALL connected browsers
 *
 * Why WebSocket instead of HTTP?
 * HTTP is request-response: the browser must ask "any new data?" repeatedly (polling).
 * WebSocket keeps the connection open — the server pushes data the instant it arrives.
 * This is what enables real-time updates on the dashboard.
 *
 * Neden HTTP yerine WebSocket?
 * HTTP istek-yanıt modelidir: tarayıcı sürekli "yeni veri var mı?" diye sormalıdır (polling).
 * WebSocket bağlantıyı açık tutar — sunucu veriyi geldiği anda iletir.
 * Bu, paneldeki gerçek zamanlı güncellemeleri mümkün kılar.
 */

const mqtt = require("mqtt");
const { WebSocketServer } = require("ws");

// --- Configuration ---
const MQTT_BROKER = process.env.MQTT_BROKER || "mqtt://localhost:1883";
const MQTT_TOPICS = ["iot-2/evt/+/fmt/json"];
const WS_PORT = 3000;

// --- MQTT Client (Subscriber) ---
// Connect to Mosquitto broker as a subscriber
const mqttClient = mqtt.connect(MQTT_BROKER);

mqttClient.on("connect", () => {
  console.log(`[MQTT] Broker'a bağlandı: ${MQTT_BROKER}`);
  // Subscribe to both simulator and Contiki topic patterns
  mqttClient.subscribe(MQTT_TOPICS, (err) => {
    if (err) {
      console.error(`[MQTT] Abone olma hatası: ${err.message}`);
    } else {
      console.log(`[MQTT] Abone olundu: ${MQTT_TOPICS.join(", ")}`);
    }
  });
});

mqttClient.on("error", (err) => {
  console.error(`[MQTT] Hata: ${err.message}`);
  console.error("Mosquitto'nun çalıştığından emin olun: mosquitto -v");
});

// --- WebSocket Server ---
// Create a WebSocket server that browsers will connect to
const wss = new WebSocketServer({ port: WS_PORT });

console.log(`[WebSocket] Sunucu başlatıldı: ws://localhost:${WS_PORT}`);

wss.on("connection", (ws) => {
  console.log(
    `[WebSocket] Yeni istemci bağlandı (toplam: ${wss.clients.size})`
  );

  ws.on("close", () => {
    console.log(
      `[WebSocket] İstemci ayrıldı (toplam: ${wss.clients.size})`
    );
  });
});

// --- Bridge: MQTT → WebSocket ---
// When a message arrives from MQTT, broadcast it to all WebSocket clients
mqttClient.on("message", (topic, message) => {
  const rawPayload = message.toString();
  let payload = normalizePayload(topic, rawPayload);

  if (!payload) {
    console.warn(`[MQTT] Geçersiz payload atlandı (topic=${topic})`);
    return;
  }

  const outgoing = JSON.stringify(payload);
  console.log(`[MQTT → WS] topic=${topic} payload=${outgoing}`);

  // Broadcast to every connected browser
  wss.clients.forEach((client) => {
    if (client.readyState === client.OPEN) {
      client.send(outgoing);
    }
  });
});

function normalizePayload(topic, rawPayload) {
  let parsed;
  try {
    parsed = JSON.parse(rawPayload);
  } catch {
    return null;
  }

  // Contiki default payload format:
  // {"d":{"Platform":"native","Seq #":1,...}}
  if (topic.startsWith("iot-2/evt/")) {
    const d = parsed && typeof parsed === "object" ? parsed.d || {} : {};
    return {
      temperature: toNumberOrNull(d.temperature ?? d["Temperature"]),
      humidity: toNumberOrNull(d.humidity ?? d["Humidity"]),
      timestamp: new Date().toISOString(),
      device_id: d.device_id || d["Device ID"] || d.Platform || "contiki-node",
      source: "contiki-ng",
      topic,
      raw: parsed,
    };
  }

  return null;
}

function toNumberOrNull(value) {
  if (value === undefined || value === null || value === "") {
    return null;
  }
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : null;
}
