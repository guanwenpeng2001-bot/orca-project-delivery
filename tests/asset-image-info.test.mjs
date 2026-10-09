import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { deflateSync } from 'node:zlib';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const fixtureRoot = path.join(root, 'tests', 'fixtures', 'capability');
const inspector = 'skills/image-generation/scripts/image-info.mjs';

function run(args) {
  return spawnSync(process.execPath, [path.join(root, inspector), ...args], {
    cwd: root,
    encoding: 'utf8',
    env: { PATH: process.env.PATH, SystemRoot: process.env.SystemRoot },
    timeout: 15000,
  });
}

function report(file) {
  const result = run(['--input', file]);
  assert.equal(result.status, 0, result.stderr);
  return JSON.parse(result.stdout);
}

function pngChunk(type, data) {
  const name = Buffer.from(type, 'ascii');
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  let crc = 0xffffffff;
  for (const buffer of [name, data]) {
    for (const byte of buffer) {
      crc ^= byte;
      for (let bit = 0; bit < 8; bit += 1) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
    }
  }
  const checksum = Buffer.alloc(4);
  checksum.writeUInt32BE((crc ^ 0xffffffff) >>> 0);
  return Buffer.concat([length, name, data, checksum]);
}

const samples = {
  'asset-image-sample.png': () => {
    const header = Buffer.alloc(13);
    header.writeUInt32BE(8, 0);
    header.writeUInt32BE(4, 4);
    header[8] = 8;
    header[9] = 6;
    return Buffer.concat([
      Buffer.from('89504e470d0a1a0a', 'hex'),
      pngChunk('IHDR', header),
      pngChunk('IDAT', deflateSync(Buffer.alloc(4 * (8 * 4 + 1)))),
      pngChunk('IEND', Buffer.alloc(0)),
    ]);
  },
  'asset-image-sample.jpg': () => Buffer.concat([
    Buffer.from([0xff, 0xd8]),
    Buffer.from([0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00]),
    Buffer.from([0xff, 0xc0, 0x00, 0x11, 0x08, 0x00, 0x10, 0x00, 0x20, 0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x00, 0x03, 0x11, 0x00]),
    Buffer.from([0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3f, 0x00, 0x00, 0xff, 0xd9]),
  ]),
  'asset-image-sample.webp': () => {
    const vp8x = Buffer.alloc(10);
    vp8x[0] = 0x10;
    vp8x.writeUIntLE(19, 4, 3);
    vp8x.writeUIntLE(9, 7, 3);
    const body = Buffer.concat([Buffer.from('VP8X'), Buffer.from([10, 0, 0, 0]), vp8x]);
    const riff = Buffer.alloc(12);
    riff.write('RIFF', 0);
    riff.writeUInt32LE(4 + body.length, 4);
    riff.write('WEBP', 8);
    return Buffer.concat([riff, body]);
  },
};

function sample(directory, name) {
  const file = path.join(directory, name);
  writeFileSync(file, samples[name]());
  return file;
}

test('PNG, JPEG and WebP headers report format, dimensions and alpha without decoding pixels', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'asset-info-samples-'));
  try {
    assert.deepEqual(report(sample(directory, 'asset-image-sample.png')), {
      format: 'png', width: 8, height: 4, alpha: true, colorType: 'rgba',
    });
    assert.deepEqual(report(sample(directory, 'asset-image-sample.jpg')), {
      format: 'jpeg', width: 32, height: 16, alpha: false, colorType: 'rgb',
    });
    assert.deepEqual(report(sample(directory, 'asset-image-sample.webp')), {
      format: 'webp', width: 20, height: 10, alpha: true, colorType: 'rgba',
    });
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('a truncated PNG and a JPEG without a start-of-frame marker are rejected', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'asset-info-'));
  try {
    const truncated = path.join(directory, 'cut.png');
    writeFileSync(truncated, samples['asset-image-sample.png']().subarray(0, 20));
    const cut = run(['--input', truncated]);
    assert.equal(cut.status, 1);
    assert.match(cut.stderr, /truncated/);

    const frameless = path.join(directory, 'frameless.jpg');
    writeFileSync(frameless, Buffer.from([0xff, 0xd8, 0xff, 0xd9]));
    const missing = run(['--input', frameless]);
    assert.equal(missing.status, 1);
    assert.match(missing.stderr, /start of frame/);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('VP8 and VP8L WebP headers report their own dimensions and alpha', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'asset-info-variants-'));
  try {
    const lossy = Buffer.alloc(30);
    lossy.write('RIFF', 0);
    lossy.writeUInt32LE(22, 4);
    lossy.write('WEBPVP8 ', 8);
    lossy.writeUInt32LE(10, 16);
    lossy[23] = 0x9d;
    lossy[24] = 0x01;
    lossy[25] = 0x2a;
    lossy.writeUInt16LE(0x8010, 26);
    lossy.writeUInt16LE(0x400c, 28);
    assert.deepEqual(report(write(directory, 'lossy.webp', lossy)), {
      format: 'webp', width: 16, height: 12, alpha: false, colorType: 'rgb',
    });

    const lossless = Buffer.alloc(25);
    lossless.write('RIFF', 0);
    lossless.writeUInt32LE(17, 4);
    lossless.write('WEBPVP8L', 8);
    lossless.writeUInt32LE(5, 16);
    lossless.writeUInt32LE((6 << 14) | 9, 21);
    lossless[24] = 0x10;
    assert.deepEqual(report(write(directory, 'lossless.webp', lossless)), {
      format: 'webp', width: 10, height: 7, alpha: true, colorType: 'rgba',
    });
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

function write(directory, name, bytes) {
  const file = path.join(directory, name);
  writeFileSync(file, bytes);
  return file;
}

test('a WebP whose declared chunk runs past the file is rejected', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'asset-info-webp-'));
  try {
    const file = path.join(directory, 'short.webp');
    const bytes = samples['asset-image-sample.webp']();
    writeFileSync(file, bytes.subarray(0, bytes.length - 4));
    const result = run(['--input', file]);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /truncated/);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
