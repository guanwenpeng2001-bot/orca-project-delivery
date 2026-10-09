import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { deflateSync, inflateSync } from 'node:zlib';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const resizer = 'skills/image-compression/scripts/png-resize.mjs';

function run(args) {
  return spawnSync(process.execPath, [path.join(root, resizer), ...args], {
    cwd: root,
    encoding: 'utf8',
    env: { PATH: process.env.PATH, SystemRoot: process.env.SystemRoot },
    timeout: 20000,
  });
}

function chunk(type, data) {
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

function ihdr(width, height, colorType) {
  const data = Buffer.alloc(13);
  data.writeUInt32BE(width, 0);
  data.writeUInt32BE(height, 4);
  data[8] = 8;
  data[9] = colorType;
  return data;
}

function png(width, height, colorType, scanlines, extras = []) {
  const channels = colorType === 6 ? 4 : 3;
  const rows = scanlines.map((row) => Buffer.from([0, ...row]));
  for (const row of rows) assert.equal(row.length, 1 + width * channels);
  return Buffer.concat([
    Buffer.from('89504e470d0a1a0a', 'hex'),
    chunk('IHDR', ihdr(width, height, colorType)),
    ...extras,
    chunk('IDAT', deflateSync(Buffer.concat(rows), { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function averageBlock(rows, sourceWidth, targetX, targetY, targetSize, channels) {
  const scale = sourceWidth / targetSize;
  const top = targetY * scale;
  const left = targetX * scale;
  const totals = Array(channels).fill(0);
  let covered = 0;
  for (let y = Math.floor(top); y < Math.ceil(top + scale); y += 1) {
    const weightY = Math.min(top + scale, y + 1) - Math.max(top, y);
    for (let x = Math.floor(left); x < Math.ceil(left + scale); x += 1) {
      const weight = weightY * (Math.min(left + scale, x + 1) - Math.max(left, x));
      covered += weight;
      for (let channel = 0; channel < channels; channel += 1) totals[channel] += rows[y][(x * channels) + channel] * weight;
    }
  }
  return totals.map((total) => Math.round(total / covered));
}

function decode(source) {
  assert.equal(source.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
  const chunks = [];
  for (let offset = 8; offset < source.length;) {
    const length = source.readUInt32BE(offset);
    const type = source.toString('ascii', offset + 4, offset + 8);
    chunks.push({ type, data: source.subarray(offset + 8, offset + 8 + length) });
    offset += 12 + length;
  }
  assert.deepEqual(chunks.map(({ type }) => type).filter((type) => ['IHDR', 'IDAT', 'IEND'].includes(type)), ['IHDR', 'IDAT', 'IEND']);
  const header = chunks[0].data;
  const width = header.readUInt32BE(0);
  const height = header.readUInt32BE(4);
  const colorType = header[9];
  const channels = colorType === 6 ? 4 : 3;
  const inflated = inflateSync(Buffer.concat(chunks.filter(({ type }) => type === 'IDAT').map(({ data }) => data)));
  const stride = width * channels;
  const rows = [];
  let previous = Buffer.alloc(stride);
  for (let y = 0; y < height; y += 1) {
    const filter = inflated[y * (stride + 1)];
    const row = Buffer.from(inflated.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1)));
    for (let index = 0; index < stride; index += 1) {
      const left = index >= channels ? row[index - channels] : 0;
      const up = previous[index];
      const upLeft = index >= channels ? previous[index - channels] : 0;
      if (filter === 1) row[index] = (row[index] + left) & 255;
      else if (filter === 2) row[index] = (row[index] + up) & 255;
      else if (filter === 3) row[index] = (row[index] + Math.floor((left + up) / 2)) & 255;
      else if (filter === 4) {
        const estimate = left + up - upLeft;
        const distances = [Math.abs(estimate - left), Math.abs(estimate - up), Math.abs(estimate - upLeft)];
        row[index] = (row[index] + [left, up, upLeft][distances.indexOf(Math.min(...distances))]) & 255;
      }
    }
    rows.push([...row]);
    previous = row;
  }
  return { width, height, colorType, rows };
}

test('a 512px RGBA master resizes to the declared web sizes with exact box-average pixels', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'asset-resize-'));
  try {
    const master = path.join(directory, 'master.png');
    const width = 512;
    const rows = Array.from({ length: width }, (_row, y) => Array.from({ length: width * 4 }, (_column, index) => {
      const x = Math.floor(index / 4);
      return [x & 255, y & 255, (x + y) & 255, x < 256 ? 128 : 255][index % 4];
    }));
    writeFileSync(master, png(width, width, 6, rows));
    for (const size of [256, 180, 32, 16]) {
      const output = path.join(directory, `icon-${size}.png`);
      writeFileSync(output, Buffer.from('do-not-touch'));
      const result = run(['--input', master, '--output', output, '--width', String(size), '--height', String(size)]);
      assert.equal(result.status, 0, result.stderr);
      const report = JSON.parse(result.stdout);
      assert.equal(report.status, 'resized');
      assert.equal(report.width, size);
      assert.equal(report.height, size);
      assert.equal(report.alpha, true);
      const decoded = decode(readFileSync(output));
      assert.equal(decoded.colorType, 6);
      assert.deepEqual(decoded.rows[0].slice(0, 4), averageBlock(rows, width, 0, 0, size, 4));
      assert.deepEqual(decoded.rows[0].slice(-4), averageBlock(rows, width, size - 1, 0, size, 4));
      assert.equal(decoded.rows[0][3], 128, 'alpha on the left half must survive averaging');
      assert.equal(decoded.rows[0].at(-1), 255);
    }
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('an RGB master keeps exact color and gains no alpha channel', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'asset-resize-rgb-'));
  try {
    const master = path.join(directory, 'master.png');
    const rows = Array.from({ length: 8 }, (_row, y) => Array.from({ length: 24 }, (_column, index) => [index * 10, y * 20, 7][index % 3]));
    writeFileSync(master, png(8, 8, 2, rows));
    const output = path.join(directory, 'small.png');
    const result = run(['--input', master, '--output', output, '--width', '4', '--height', '4']);
    assert.equal(result.status, 0, result.stderr);
    const decoded = decode(readFileSync(output));
    assert.equal(decoded.colorType, 2);
    assert.deepEqual(decoded.rows[0].slice(0, 3), averageBlock(rows, 8, 0, 0, 4, 3));
    assert.equal(JSON.parse(result.stdout).alpha, false);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('a size that is not smaller on both axes is rejected and the destination stays untouched', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'asset-resize-reject-'));
  try {
    const master = path.join(directory, 'master.png');
    writeFileSync(master, png(8, 8, 2, Array.from({ length: 8 }, () => Array(24).fill(9))));
    const output = path.join(directory, 'kept.png');
    writeFileSync(output, Buffer.from('original-destination'));
    const result = run(['--input', master, '--output', output, '--width', '8', '--height', '4']);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /not smaller/);
    assert.equal(readFileSync(output).toString(), 'original-destination');
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('a truncated PNG is rejected before any output is written', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'asset-resize-truncated-'));
  try {
    const master = path.join(directory, 'broken.png');
    const intact = png(4, 4, 2, Array.from({ length: 4 }, () => Array(12).fill(3)));
    writeFileSync(master, intact.subarray(0, intact.length - 5));
    const output = path.join(directory, 'out.png');
    const result = run(['--input', master, '--output', output, '--width', '2', '--height', '2']);
    assert.equal(result.status, 1);
    assert.equal(readFileSync(output, { flag: 'a+' }).length, 0);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('filtered scanlines are reconstructed before resampling, and a bad filter is rejected', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'asset-resize-filter-'));
  try {
    const channels = 3;
    const rows = [Array.from({ length: 6 }, (_unused, index) => (index + 1) * 30), Array.from({ length: 6 }, (_unused, index) => 200 - index * 20)];
    const filtered = Buffer.concat([Buffer.from([1]), Buffer.from(rows[0]), Buffer.from([2]), Buffer.from(rows[1])]);
    for (let index = channels; index < rows[0].length; index += 1) filtered[1 + index] = (rows[0][index] - rows[0][index - channels]) & 255;
    for (let index = 0; index < rows[1].length; index += 1) filtered[1 + rows[0].length + 1 + index] = (rows[1][index] - rows[0][index]) & 255;
    const master = path.join(directory, 'filtered.png');
    writeFileSync(master, Buffer.concat([
      Buffer.from('89504e470d0a1a0a', 'hex'),
      chunk('IHDR', ihdr(2, 2, 2)),
      chunk('IDAT', deflateSync(filtered, { level: 9 })),
      chunk('IEND', Buffer.alloc(0)),
    ]));
    const output = path.join(directory, 'one.png');
    const result = run(['--input', master, '--output', output, '--width', '1', '--height', '1']);
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(decode(readFileSync(output)).rows[0], averageBlock(rows, 2, 0, 0, 1, 3));

    filtered[0] = 7;
    writeFileSync(master, Buffer.concat([
      Buffer.from('89504e470d0a1a0a', 'hex'),
      chunk('IHDR', ihdr(2, 2, 2)),
      chunk('IDAT', deflateSync(filtered, { level: 9 })),
      chunk('IEND', Buffer.alloc(0)),
    ]));
    const rejected = run(['--input', master, '--output', output, '--width', '1', '--height', '1']);
    assert.equal(rejected.status, 1);
    assert.match(rejected.stderr, /invalid filter/);
    assert.deepEqual(decode(readFileSync(output)).rows[0], averageBlock(rows, 2, 0, 0, 1, 3));
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

function masterPng(size) {
  const stride = size * 4;
  const scanlines = Buffer.alloc((stride + 1) * size);
  for (let y = 0; y < size; y += 1) {
    const row = scanlines.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < size; x += 1) {
      const index = x * 4;
      row[index] = x & 255;
      row[index + 1] = y & 255;
      row[index + 2] = (x ^ y) & 255;
      row[index + 3] = x < size / 2 ? 128 : 255;
    }
  }
  return Buffer.concat([
    Buffer.from('89504e470d0a1a0a', 'hex'),
    chunk('IHDR', ihdr(size, size, 6)),
    chunk('IDAT', deflateSync(scanlines, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

test('a generated 512px master is the 512 entry and exports the four smaller declared sizes', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'asset-resize-fixture-'));
  try {
    const fixture = path.join(directory, 'master.png');
    writeFileSync(fixture, masterPng(512));
    const master = decode(readFileSync(fixture));
    assert.equal(master.width, 512);
    assert.equal(master.height, 512);
    assert.equal(master.colorType, 6);
    for (const size of [192, 180, 32, 16]) {
      const output = path.join(directory, size + '.png');
      const result = run(['--input', fixture, '--output', output, '--width', String(size), '--height', String(size)]);
      assert.equal(result.status, 0, result.stderr);
      const decoded = decode(readFileSync(output));
      assert.equal(decoded.width, size);
      assert.equal(decoded.height, size);
      assert.equal(decoded.colorType, 6);
    }
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('an RGB color key is kept as real alpha instead of being dropped', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'asset-resize-trns-'));
  try {
    const master = path.join(directory, 'keyed.png');
    const key = Buffer.from([0x00, 0x0a, 0x00, 0x14, 0x00, 0x1e]);
    const row = [10, 20, 30, 40, 50, 60];
    writeFileSync(master, png(2, 2, 2, [row, row], [chunk('tRNS', key)]));
    const output = path.join(directory, 'out.png');
    const result = run(['--input', master, '--output', output, '--width', '1', '--height', '1']);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(JSON.parse(result.stdout).alpha, true);
    const decoded = decode(readFileSync(output));
    assert.equal(decoded.colorType, 6);
    assert.deepEqual(decoded.rows[0].slice(0, 4), [25, 35, 45, 128]);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('a non-text ancillary chunk is rejected and the destination stays untouched', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'asset-resize-ancillary-'));
  try {
    const master = path.join(directory, 'gamma.png');
    const gamma = Buffer.alloc(4);
    gamma.writeUInt32BE(45455);
    writeFileSync(master, png(2, 2, 2, [Array(6).fill(8), Array(6).fill(8)], [chunk('gAMA', gamma)]));
    const output = path.join(directory, 'out.png');
    writeFileSync(output, Buffer.from('untouched'));
    const result = run(['--input', master, '--output', output, '--width', '1', '--height', '1']);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /gAMA/);
    assert.equal(readFileSync(output).toString(), 'untouched');

    const keyed = Buffer.from([0x00, 0x0a, 0x00, 0x14, 0x00, 0x1e]);
    const combined = path.join(directory, 'combined.png');
    writeFileSync(combined, png(2, 2, 2, [Array(6).fill(8), Array(6).fill(8)], [chunk('tRNS', keyed), chunk('gAMA', gamma)]));
    writeFileSync(output, Buffer.from('untouched'));
    const both = run(['--input', combined, '--output', output, '--width', '1', '--height', '1']);
    assert.equal(both.status, 1);
    assert.match(both.stderr, /gAMA/);
    assert.equal(readFileSync(output).toString(), 'untouched');
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('palette, 16-bit, interlaced and oversized PNGs are rejected before writing', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'asset-resize-unsupported-'));
  try {
    const output = path.join(directory, 'out.png');
    const palette = png(2, 1, 3, [Array(6).fill(1)]);
    const sixteen = ihdr(2, 1, 2);
    sixteen[8] = 16;
    const interlaced = ihdr(2, 1, 2);
    interlaced[12] = 1;
    const oversized = ihdr(5000, 5000, 2);
    const cases = [
      ['palette', palette],
      ['sixteen-bit', framed(sixteen, Buffer.alloc(2 * (2 * 6 + 1)))],
      ['interlaced', framed(interlaced, Buffer.alloc(1 + 6))],
      ['oversized', framed(oversized, Buffer.alloc(1))],
      ['wide-key', png(2, 2, 2, [Array(6).fill(8), Array(6).fill(8)], [chunk('tRNS', Buffer.from([0x01, 0x00, 0x00, 0x00, 0x00, 0x00]))])],
    ];
    for (const [name, bytes] of cases) {
      const master = path.join(directory, name + '.png');
      writeFileSync(master, bytes);
      writeFileSync(output, Buffer.from('untouched'));
      const result = run(['--input', master, '--output', output, '--width', '1', '--height', '1']);
      assert.equal(result.status, 1, name);
      assert.equal(readFileSync(output).toString(), 'untouched', name);
    }
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

function framed(header, scanlines) {
  return Buffer.concat([
    Buffer.from('89504e470d0a1a0a', 'hex'),
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(scanlines)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}
