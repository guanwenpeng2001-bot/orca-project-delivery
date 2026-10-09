import { readFileSync } from 'node:fs';
import { deflateSync, inflateSync, crc32 } from 'node:zlib';
import { saveOutput } from '../../../scripts/capability-runtime.mjs';

const channelsFor = { 2: 3, 6: 4 };
const keptChunks = ['IHDR', 'IDAT', 'IEND', 'tEXt', 'tRNS'];
const MAX_SOURCE_PIXELS = 4096 * 4096;

try {
  const values = readArgs(process.argv.slice(2));
  const targetWidth = readDimension(values.width, 'width');
  const targetHeight = readDimension(values.height, 'height');
  const source = readFileSync(values.input);
  const decoded = decodePng(source);
  if (targetWidth >= decoded.width || targetHeight >= decoded.height) throw new Error('requested size is not smaller on both axes');
  const expanded = applyColorKey(decoded);
  const resized = boxAverage(expanded, targetWidth, targetHeight);
  saveOutput(values.output, encodePng(resized));
  process.stdout.write(`${JSON.stringify({
    status: 'resized', width: targetWidth, height: targetHeight, alpha: expanded.channels === 4, output: values.output,
  })}\n`);
} catch (error) {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
}

function decodePng(source) {
  if (source.length < 8 || source.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a') throw new Error('input is not a PNG');
  const chunks = [];
  for (let offset = 8; offset < source.length;) {
    if (offset + 12 > source.length) throw new Error('truncated chunk');
    const length = source.readUInt32BE(offset);
    if (length > source.length - offset - 12) throw new Error('truncated chunk data');
    const type = source.toString('ascii', offset + 4, offset + 8);
    if (!/^[A-Za-z]{4}$/.test(type)) throw new Error('invalid chunk type');
    const data = source.subarray(offset + 8, offset + 8 + length);
    if ((crc32(source.subarray(offset + 4, offset + 8 + length)) >>> 0) !== source.readUInt32BE(offset + 8 + length)) throw new Error(`CRC mismatch: ${type}`);
    chunks.push({ type, data });
    offset += 12 + length;
    if (type === 'IEND' && offset !== source.length) throw new Error('trailing PNG data');
  }
  if (chunks[0]?.type !== 'IHDR' || chunks[0].data.length !== 13 || chunks.at(-1)?.type !== 'IEND' || chunks.at(-1).data.length) throw new Error('invalid PNG header or end');
  const header = chunks[0].data;
  const width = header.readUInt32BE(0);
  const height = header.readUInt32BE(4);
  const channels = channelsFor[header[9]];
  if (!width || !height || header[8] !== 8 || !channels || header[10] || header[11] || header[12]) throw new Error('only 8-bit non-interlaced RGB and RGBA PNG are supported');
  if (width > MAX_SOURCE_PIXELS / height) throw new Error('PNG exceeds 4096x4096 pixel limit');
  const first = chunks.findIndex(({ type }) => type === 'IDAT');
  const last = chunks.findLastIndex(({ type }) => type === 'IDAT');
  if (first < 0 || chunks.slice(first, last + 1).some(({ type }) => type !== 'IDAT')) throw new Error('invalid IDAT sequence');
  const dropped = chunks.find(({ type }) => !keptChunks.includes(type));
  if (dropped) throw new Error('unsupported PNG chunk: ' + dropped.type);
  const transparency = colorKey(chunks, header[9]);
  const stride = width * channels;
  let inflated;
  try {
    inflated = inflateSync(Buffer.concat(chunks.slice(first, last + 1).map(({ data }) => data)), { maxOutputLength: (stride + 1) * height });
  } catch {
    throw new Error('PNG pixel data could not be inflated');
  }
  if (inflated.length !== (stride + 1) * height) throw new Error('invalid scanline length');
  const rows = [];
  let previous = Buffer.alloc(stride);
  for (let y = 0; y < height; y += 1) {
    const filter = inflated[y * (stride + 1)];
    if (filter > 4) throw new Error('invalid filter');
    const row = Buffer.from(inflated.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1)));
    for (let index = 0; index < stride; index += 1) {
      const left = index >= channels ? row[index - channels] : 0;
      const up = previous[index];
      const upLeft = index >= channels ? previous[index - channels] : 0;
      if (filter === 1) row[index] = (row[index] + left) & 255;
      else if (filter === 2) row[index] = (row[index] + up) & 255;
      else if (filter === 3) row[index] = (row[index] + Math.floor((left + up) / 2)) & 255;
      else if (filter === 4) row[index] = (row[index] + paeth(left, up, upLeft)) & 255;
    }
    rows.push(row);
    previous = row;
  }
  return { width, height, channels, rows, transparency };
}

function colorKey(chunks, colorType) {
  const chunk = chunks.find(({ type }) => type === 'tRNS');
  if (!chunk) return null;
  if (colorType !== 2 || chunk.data.length !== 6) throw new Error('unsupported PNG transparency');
  const key = [chunk.data.readUInt16BE(0), chunk.data.readUInt16BE(2), chunk.data.readUInt16BE(4)];
  if (key.some((value) => value > 255)) throw new Error('unsupported PNG transparency');
  return key;
}

function applyColorKey(image) {
  if (!image.transparency) return image;
  const rows = image.rows.map((source) => {
    const row = Buffer.alloc(source.length + source.length / 3);
    for (let index = 0; index < source.length; index += 3) {
      const target = (index / 3) * 4;
      source.copy(row, target, index, index + 3);
      const matched = image.transparency.every((value, channel) => value === source[index + channel]);
      row[target + 3] = matched ? 0 : 255;
    }
    return row;
  });
  return { width: image.width, height: image.height, channels: 4, rows };
}

function paeth(left, up, upLeft) {
  const estimate = left + up - upLeft;
  const distances = [Math.abs(estimate - left), Math.abs(estimate - up), Math.abs(estimate - upLeft)];
  return [left, up, upLeft][distances.indexOf(Math.min(...distances))];
}

function boxAverage(source, targetWidth, targetHeight) {
  const rows = [];
  for (let y = 0; y < targetHeight; y += 1) {
    const row = Buffer.alloc(targetWidth * source.channels);
    const top = (y * source.height) / targetHeight;
    const bottom = ((y + 1) * source.height) / targetHeight;
    for (let x = 0; x < targetWidth; x += 1) {
      const left = (x * source.width) / targetWidth;
      const right = ((x + 1) * source.width) / targetWidth;
      const totals = Array(source.channels).fill(0);
      let covered = 0;
      for (let sourceY = Math.floor(top); sourceY < Math.ceil(bottom); sourceY += 1) {
        const weightY = Math.min(bottom, sourceY + 1) - Math.max(top, sourceY);
        const sourceRow = source.rows[sourceY];
        for (let sourceX = Math.floor(left); sourceX < Math.ceil(right); sourceX += 1) {
          const weight = weightY * (Math.min(right, sourceX + 1) - Math.max(left, sourceX));
          covered += weight;
          const start = sourceX * source.channels;
          for (let channel = 0; channel < source.channels; channel += 1) totals[channel] += sourceRow[start + channel] * weight;
        }
      }
      for (let channel = 0; channel < source.channels; channel += 1) row[(x * source.channels) + channel] = Math.round(totals[channel] / covered);
    }
    rows.push(row);
  }
  return { width: targetWidth, height: targetHeight, channels: source.channels, rows };
}

function encodePng(image) {
  const stride = image.width * image.channels;
  const scanlines = Buffer.alloc((stride + 1) * image.height);
  image.rows.forEach((row, y) => row.copy(scanlines, y * (stride + 1) + 1));
  const header = Buffer.alloc(13);
  header.writeUInt32BE(image.width, 0);
  header.writeUInt32BE(image.height, 4);
  header[8] = 8;
  header[9] = image.channels === 4 ? 6 : 2;
  return Buffer.concat([
    Buffer.from('89504e470d0a1a0a', 'hex'),
    encodeChunk('IHDR', header),
    encodeChunk('IDAT', deflateSync(scanlines, { level: 9 })),
    encodeChunk('IEND', Buffer.alloc(0)),
  ]);
}

function encodeChunk(type, data) {
  const name = Buffer.from(type, 'ascii');
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const checksum = Buffer.alloc(4);
  checksum.writeUInt32BE(crc32(Buffer.concat([name, data])) >>> 0);
  return Buffer.concat([length, name, data, checksum]);
}

function readDimension(value, name) {
  if (!/^[1-9]\d*$/.test(value ?? '')) throw new Error(`${name} must be a positive integer`);
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed)) throw new Error(`${name} must be a positive integer`);
  return parsed;
}

function readArgs(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    const name = argv[index];
    if (!/^--[a-z]+$/.test(name ?? '') || argv[index + 1] === undefined) throw new Error('invalid arguments');
    result[name.slice(2)] = argv[index + 1];
  }
  for (const name of ['input', 'output', 'width', 'height']) {
    if (!result[name]) throw new Error(`missing --${name}`);
  }
  return result;
}
