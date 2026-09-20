import { describe, it, expect } from 'vitest';
import { buildPairingQrPayload, PAIRING_QR_I18N } from '../pairingQr';
import { QRCodeSVG } from 'qrcode.react';
import React from 'react';
import ReactDOMServer from 'react-dom/server';
import jsQR from 'jsqr';

describe('buildPairingQrPayload', () => {
  it('encodes standard 6-character code into smritikunj:// deep link', () => {
    const payload = buildPairingQrPayload('552785');
    expect(payload).toBe('smritikunj://pair?code=552785');
  });

  it('strips leading PAIR- prefix if present', () => {
    const payload = buildPairingQrPayload('PAIR-984210');
    expect(payload).toBe('smritikunj://pair?code=984210');
  });

  it('trims leading and trailing whitespace', () => {
    const payload = buildPairingQrPayload('  123456  ');
    expect(payload).toBe('smritikunj://pair?code=123456');
  });

  it('returns empty string for empty string or null or undefined', () => {
    expect(buildPairingQrPayload('')).toBe('');
    expect(buildPairingQrPayload('   ')).toBe('');
    expect(buildPairingQrPayload(null)).toBe('');
    expect(buildPairingQrPayload(undefined)).toBe('');
    expect(buildPairingQrPayload(123456)).toBe('');
  });

  it('contains no PII such as patient name, ID, or DOB', () => {
    const code = '742918';
    const payload = buildPairingQrPayload(code);
    expect(payload).not.toContain('name');
    expect(payload).not.toContain('patient');
    expect(payload).not.toContain('dob');
    expect(payload).toBe(`smritikunj://pair?code=${code}`);
  });

  it('has translation keys defined across en, as, bn', () => {
    ['en', 'as', 'bn'].forEach((lang) => {
      expect(PAIRING_QR_I18N[lang]).toBeDefined();
      expect(PAIRING_QR_I18N[lang].scanCaption).toBeTruthy();
      expect(PAIRING_QR_I18N[lang].securityHint).toBeTruthy();
      expect(PAIRING_QR_I18N[lang].copy).toBeTruthy();
      expect(PAIRING_QR_I18N[lang].downloadPng).toBeTruthy();
      expect(PAIRING_QR_I18N[lang].devicePaired).toBeTruthy();
      expect(PAIRING_QR_I18N[lang].showAnyway).toBeTruthy();
    });
  });

  it('successfully decodes with a standard QR reader engine to the exact payload', () => {
    const testCode = '552785';
    const payload = buildPairingQrPayload(testCode);

    const svgStr = ReactDOMServer.renderToStaticMarkup(
      React.createElement(QRCodeSVG, {
        value: payload,
        size: 296,
        level: 'M',
        includeMargin: true,
        marginSize: 4,
      })
    );

    const matchVb = svgStr.match(/viewBox="0 0 (\d+) (\d+)"/);
    expect(matchVb).not.toBeNull();
    const size = parseInt(matchVb[1], 10);

    const grid = Array.from({ length: size }, () => Array(size).fill(0));
    const pathMatch = svgStr.match(/<path fill="#000000" d="([^"]+)"/);
    expect(pathMatch).not.toBeNull();
    const d = pathMatch[1];

    const rects = d.split('z').filter(Boolean);
    for (const r of rects) {
      const m = r.match(/M\s*(\d+)[,\s]+(\d+)\s*h\s*(\d+)/i);
      if (m) {
        const x = parseInt(m[1], 10);
        const y = parseInt(m[2], 10);
        const w = parseInt(m[3], 10);
        for (let i = 0; i < w; i++) {
          grid[y][x + i] = 1;
        }
      }
    }

    const scale = 6;
    const imgDim = size * scale;
    const data = new Uint8ClampedArray(imgDim * imgDim * 4);

    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        const isBlack = grid[y][x] === 1;
        const val = isBlack ? 0 : 255;
        for (let dy = 0; dy < scale; dy++) {
          for (let dx = 0; dx < scale; dx++) {
            const px = x * scale + dx;
            const py = y * scale + dy;
            const idx = (py * imgDim + px) * 4;
            data[idx] = val;
            data[idx + 1] = val;
            data[idx + 2] = val;
            data[idx + 3] = 255;
          }
        }
      }
    }

    const decoded = jsQR(data, imgDim, imgDim);
    expect(decoded).not.toBeNull();
    expect(decoded.data).toBe('smritikunj://pair?code=552785');
  });
});
