import { readFileSync, writeFileSync } from 'node:fs';
import { deflateSync, inflateSync, crc32 } from 'node:zlib';

const values = readArgs(process.argv.slice(2));
if (values.sample) {
  writeFileSync(values.sample, samplePng());
  process.exit(0);
}
const source = readFileSync(values.input);
if (source.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a') {
  process.stderr.write('input is not a PNG\n');
  process.exit(1);
}
const chunks = [];
let idat = Buffer.alloc(0);
for (let offset = 8; offset < source.length;) {
  const length = source.readUInt32BE(offset);
  const type = source.subarray(offset + 4, offset + 8).toString('ascii');
  const data = source.subarray(offset + 8, offset + 8 + length);
  if (type === 'IDAT') idat = Buffer.concat([idat, data]);
  else chunks.push({ type, data });
  offset += 12 + length;
}
const compressed = deflateSync(inflateSync(idat), { level: 9 });
const ordered = [];
for (const chunk of chunks) {
  ordered.push(chunk);
  if (chunk.type === 'IHDR') ordered.push({ type: 'IDAT', data: compressed });
}
writeFileSync(values.output, Buffer.concat([Buffer.from('89504e470d0a1a0a', 'hex'), ...ordered.map(encodeChunk)]));

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
