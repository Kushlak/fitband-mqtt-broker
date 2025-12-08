import * as crypto from 'crypto';

export class HmacUtil {
  /**
   * Generate HMAC-SHA256 signature
   */
  static sign(data: string, secret: string): string {
    return crypto.createHmac('sha256', secret).update(data).digest('hex');
  }

  /**
   * Verify HMAC signature
   */
  static verify(data: string, secret: string, signature: string): boolean {
    const expectedSignature = this.sign(data, secret);
    const expectedBuffer = Buffer.from(expectedSignature, 'hex');
    const signatureBuffer = Buffer.from(signature, 'hex');

    if (expectedBuffer.length !== signatureBuffer.length) {
      return false;
    }

    return crypto.timingSafeEqual(expectedBuffer, signatureBuffer);
  }

  /**
   * Generate signature for WebSocket join event
   * Format: deviceId:timestamp
   */
  static signJoin(deviceId: string, timestamp: string, secret: string): string {
    return this.sign(`${deviceId}:${timestamp}`, secret);
  }

  /**
   * Verify join event signature
   */
  static verifyJoin(
    deviceId: string,
    timestamp: string,
    secret: string,
    signature: string,
  ): boolean {
    return this.verify(`${deviceId}:${timestamp}`, secret, signature);
  }

  /**
   * Generate signature for telemetry data
   * Uses JSON stringified payload
   */
  static signTelemetry(payload: string, secret: string): string {
    return this.sign(payload, secret);
  }

  /**
   * Verify telemetry signature
   */
  static verifyTelemetry(
    payload: string,
    secret: string,
    signature: string,
  ): boolean {
    return this.verify(payload, secret, signature);
  }
}
