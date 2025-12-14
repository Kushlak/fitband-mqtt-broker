#!/usr/bin/env node
/**
 * Test WebSocket connection to Fitband MQTT Broker
 * Usage: node scripts/utils/test-websocket.js [url] [deviceId]
 */

const { io } = require('socket.io-client');
const crypto = require('crypto');

// Configuration
const WS_URL = process.argv[2] || 'http://localhost:8080';
const DEVICE_ID = process.argv[3] || 'test-device-001';
const DEVICE_SECRET = process.argv[4] || 'test-secret-key';

console.log('=== WebSocket Connection Test ===');
console.log(`URL: ${WS_URL}`);
console.log(`Device ID: ${DEVICE_ID}`);
console.log('');

// Generate HMAC signature for join event
function generateJoinSignature(deviceId, secret) {
  const timestamp = new Date().toISOString();
  const data = `${deviceId}:${timestamp}`;
  const signature = crypto.createHmac('sha256', secret).update(data).digest('hex');
  
  return { deviceId, timestamp, signature };
}

// Connect to WebSocket
const socket = io(WS_URL, {
  path: '/ws',
  transports: ['websocket', 'polling'],
  rejectUnauthorized: false, // Accept self-signed certificates
});

// Connection events
socket.on('connect', () => {
  console.log('✓ Connected to WebSocket server');
  console.log(`  Socket ID: ${socket.id}`);
  
  // Authenticate with HMAC
  const joinPayload = generateJoinSignature(DEVICE_ID, DEVICE_SECRET);
  console.log('');
  console.log('→ Sending join event with HMAC signature');
  socket.emit('join', joinPayload);
});

socket.on('joined', (data) => {
  console.log('✓ Authentication successful');
  console.log('  Response:', JSON.stringify(data, null, 2));
  
  // Send test telemetry
  console.log('');
  console.log('→ Sending test telemetry');
  const telemetry = {
    deviceId: DEVICE_ID,
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
  
  socket.emit('telemetry', telemetry);
});

socket.on('error', (error) => {
  console.error('✗ Error:', error.message || error);
  process.exit(1);
});

socket.on('disconnect', (reason) => {
  console.log('✗ Disconnected:', reason);
  process.exit(0);
});

socket.on('connect_error', (err) => {
  console.error('✗ Connection error:', err.message);
  process.exit(1);
});

socket.on('telemetry:new', (data) => {
  console.log('✓ Telemetry broadcast received');
  console.log('  Device:', data.deviceId);
  console.log('  Message ID:', data.telemetry.messageId);
});

socket.on('device:connected', (data) => {
  console.log('✓ Device connected event:', data.deviceId);
});

socket.on('device:disconnected', (data) => {
  console.log('✗ Device disconnected event:', data.deviceId);
});

// Auto-disconnect after 5 seconds
setTimeout(() => {
  console.log('');
  console.log('✓ Test completed successfully');
  socket.disconnect();
  process.exit(0);
}, 5000);

// Handle Ctrl+C
process.on('SIGINT', () => {
  console.log('');
  console.log('Disconnecting...');
  socket.disconnect();
  process.exit(0);
});

