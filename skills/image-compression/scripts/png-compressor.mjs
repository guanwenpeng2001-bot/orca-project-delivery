import { readFileSync, writeFileSync } from 'node:fs';
import { deflateSync, inflateSync, crc32 } from 'node:zlib';
import { saveOutput } from '../../../scripts/capability-runtime.mjs';

try {
  const values = readArgs(process.argv.slice(2));
  if (values.sample) {
    writeFileSync(values.sample, samplePng());
  } else {
    const source = readFileSync(values.input);
    if (source.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a') throw new Error('input is not a PNG');
    const chunks = [];
    for (let offset = 8; offset < source.length;) {
      if (offset + 12 > source.length) throw new Error('truncated chunk');
      const length = source.readUInt32BE(offset);
      if (length > source.length - offset - 12) throw new Error('truncated chunk data');
      const type = source.toString('ascii', offset + 4, offset + 8);
      if (!/^[A-Za-z]{4}$/.test(type)) throw new Error('invalid chunk type');
      const data = source.subarray(offset + 8, offset + 8 + length);
      if (crc32(source.subarray(offset + 4, offset + 8 + length)) !== source.readUInt32BE(offset + 8 + length)) throw new Error(`CRC mismatch: ${type}`);
      chunks.push({ type, data });
      offset += 12 + length;
      if (type === 'IEND' && offset !== source.length) throw new Error('trailing PNG data');
    }
    if (chunks[0]?.type !== 'IHDR' || chunks[0].data.length !== 13 || chunks.at(-1)?.type !== 'IEND' || chunks.at(-1).data.length) throw new Error('invalid PNG header or end');
    if (chunks.filter(({ type }) => type === 'IHDR').length !== 1) throw new Error('duplicate header');
    const header = chunks[0].data;
    const width = header.readUInt32BE(0); const height = header.readUInt32BE(4);
    const depth = header[8]; const color = header[9];
    const channels = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[color];
    const depths = { 0: [1, 2, 4, 8, 16], 2: [8, 16], 3: [1, 2, 4, 8], 4: [8, 16], 6: [8, 16] }[color];
    if (!width || !height || !depths?.includes(depth) || header[10] || header[11] || header[12]) throw new Error('unsupported PNG encoding (non-interlaced only)');
    const first = chunks.findIndex(({ type }) => type === 'IDAT');
    const last = chunks.findLastIndex(({ type }) => type === 'IDAT');
    if (first < 0 || chunks.slice(first, last + 1).some(({ type }) => type !== 'IDAT')) throw new Error('invalid IDAT sequence');
    const palette = chunks.findIndex(({ type }) => type === 'PLTE');
    if ((color === 3 && palette < 0) || palette > first || chunks.filter(({ type }) => type === 'PLTE').length > 1) throw new Error('invalid palette order');
    if (palette >= 0 && (!chunks[palette].data.length || chunks[palette].data.length % 3 || chunks[palette].data.length > 768)) throw new Error('invalid palette');
    if (chunks.some(({ type }) => ['acTL', 'fcTL', 'fdAT'].includes(type) || (type[0] === type[0].toUpperCase() && !['IHDR', 'PLTE', 'IDAT', 'IEND'].includes(type)))) throw new Error('unsupported PNG chunk');
    const rowBytes = Math.ceil(width * channels * depth / 8);
    const expected = (rowBytes + 1) * height;
    if (expected > 256 * 1024 * 1024) throw new Error('PNG exceeds 256 MiB scanline limit');
    const pixels = inflateSync(Buffer.concat(chunks.slice(first, last + 1).map(({ data }) => data)), { maxOutputLength: expected });
    if (pixels.length !== expected) throw new Error('invalid scanline length');
    for (let offset = 0; offset < pixels.length; offset += rowBytes + 1) if (pixels[offset] > 4) throw new Error('invalid filter');
    const compressed = deflateSync(pixels, { level: 9 });
    const ordered = [...chunks.slice(0, first), { type: 'IDAT', data: compressed }, ...chunks.slice(last + 1)];
    const output = Buffer.concat([source.subarray(0, 8), ...ordered.map(encodeChunk)]);
    if (output.length >= source.length) {
      process.stdout.write(`${JSON.stringify({ status: 'no-gain', inputBytes: source.length, candidateBytes: output.length })}\n`);
    } else {
      saveOutput(values.output, output);
      process.stdout.write(`${JSON.stringify({ status: 'compressed', inputBytes: source.length, outputBytes: output.length, output: values.output })}\n`);
    }
  }
} catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 1; }

function encodeChunk(chunk) {
  const type = Buffer.from(chunk.type, 'ascii');
  const length = Buffer.alloc(4);
  length.writeUInt32BE(chunk.data.length);
  const checksum = Buffer.alloc(4);
  checksum.writeUInt32BE(crc32(Buffer.concat([type, chunk.data])) >>> 0);
  return Buffer.concat([length, type, chunk.data, checksum]);
}

function samplePng() {
  const width = 64;
  const height = 64;
  const rows = [];
  for (let y = 0; y < height; y += 1) {
    rows.push(Buffer.from([0, ...Array.from({ length: width * 4 }, (_unused, index) => [20, 90, 140, 255][index % 4])]));
  }
  return Buffer.concat([
    Buffer.from('89504e470d0a1a0a', 'hex'),
    encodeChunk({ type: 'IHDR', data: ihdr(width, height) }),
    encodeChunk({ type: 'IDAT', data: deflateSync(Buffer.concat(rows), { level: 0 }) }),
    encodeChunk({ type: 'IEND', data: Buffer.alloc(0) }),
  ]);
}

function ihdr(width, height) {
  const data = Buffer.alloc(13);
  data.writeUInt32BE(width, 0);
  data.writeUInt32BE(height, 4);
  data[8] = 8;
  data[9] = 6;
  return data;
}

function readArgs(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    result[argv[index].replace(/^--/, '')] = argv[index + 1];
  }
  if (result.sample) return result;
  for (const name of ['input', 'output']) {
    if (!result[name]) {
      process.stderr.write(`missing --${name}\n`);
      process.exit(1);
    }
  }
  return result;
}
