#!/usr/bin/env node
/**
 * Generate HMAC signatures for WebSocket authentication
 * Usage: node scripts/utils/generate-hmac.js [deviceId] [deviceSecret]
 */

const crypto = require('crypto');

// Configuration
const deviceId = process.argv[2] || 'mock-001';
const deviceSecret = process.argv[3] || 'secret-mock-001';

console.log('=== HMAC Signature Generator ===');
console.log('');
console.log('Device ID:', deviceId);
console.log('Device Secret:', deviceSecret);
console.log('');

// Generate join signature
const timestamp = new Date().toISOString();
const joinData = `${deviceId}:${timestamp}`;
const joinSignature = crypto
  .createHmac('sha256', deviceSecret)
  .update(joinData)
  .digest('hex');

console.log('=== Join Event ===');
console.log('Timestamp:', timestamp);
console.log('Data to sign:', joinData);
console.log('Signature:', joinSignature);
console.log('');
console.log('JSON payload:');
console.log(JSON.stringify({
  deviceId,
  timestamp,
  signature: joinSignature,
}, null, 2));
console.log('');

// Generate telemetry signature
const telemetry = {
  deviceId,
  timestamp: new Date().toISOString(),
  messageId: crypto.randomUUID(),
  metrics: {
    heartRate: 72,
    stepsDelta: 15,
    caloriesDelta: 0.6,
    battery: 0.85,
  },
  motion: {
    ax: 0.123,
    ay: -0.045,
    az: 0.987,
  },
};

const telemetryString = JSON.stringify(telemetry);
const telemetrySignature = crypto
  .createHmac('sha256', deviceSecret)
  .update(telemetryString)
  .digest('hex');

console.log('=== Telemetry Event (Optional) ===');
console.log('Payload:', telemetryString);
console.log('Signature:', telemetrySignature);
console.log('');
console.log('JSON payload with signature:');
console.log(JSON.stringify({
  ...telemetry,
  signature: telemetrySignature,
}, null, 2));
console.log('');

// Usage examples
console.log('=== Usage in Socket.IO Client ===');
console.log('');
console.log('const socket = io("http://localhost:8080", { path: "/ws" });');
console.log('');
console.log('socket.on("connect", () => {');
console.log('  socket.emit("join", {');
console.log(`    deviceId: "${deviceId}",`);
console.log(`    timestamp: "${timestamp}",`);
console.log(`    signature: "${joinSignature}"`);
console.log('  });');
console.log('});');
console.log('');

