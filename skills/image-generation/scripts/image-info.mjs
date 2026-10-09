import { readFileSync } from 'node:fs';

try {
  const input = readArg(process.argv.slice(2));
  const source = readFileSync(input);
  process.stdout.write(`${JSON.stringify(inspect(source))}\n`);
} catch (error) {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
}

function inspect(source) {
  if (source.length >= 8 && source.subarray(0, 8).toString('hex') === '89504e470d0a1a0a') return inspectPng(source);
  if (source.length >= 2 && source[0] === 0xff && source[1] === 0xd8) return inspectJpeg(source);
  if (source.length >= 12 && source.toString('ascii', 0, 4) === 'RIFF' && source.toString('ascii', 8, 12) === 'WEBP') return inspectWebp(source);
  throw new Error('unrecognized image format');
}

function inspectPng(source) {
  if (source.length < 24) throw new Error('truncated PNG header');
  const length = source.readUInt32BE(8);
  if (source.toString('ascii', 12, 16) !== 'IHDR' || length !== 13) throw new Error('PNG header missing');
  if (source.length < 33) throw new Error('truncated PNG header');
  const colorType = source[25];
  const described = { 0: ['gray', false], 2: ['rgb', false], 3: ['indexed', false], 4: ['gray', true], 6: ['rgba', true] }[colorType];
  if (!described) throw new Error('invalid PNG color type');
  return { format: 'png', width: source.readUInt32BE(16), height: source.readUInt32BE(20), alpha: described[1] || pngHasTransparency(source), colorType: described[0] };
}

function pngHasTransparency(source) {
  for (let offset = 33; offset + 8 <= source.length;) {
    const length = source.readUInt32BE(offset);
    const type = source.toString('ascii', offset + 4, offset + 8);
    if (offset + 12 + length > source.length || type === 'IDAT') return false;
    if (type === 'tRNS') return length > 0;
    offset += 12 + length;
  }
  return false;
}

function inspectJpeg(source) {
  let offset = 2;
  while (offset + 4 <= source.length) {
    if (source[offset] !== 0xff) throw new Error('malformed JPEG marker');
    while (source[offset] === 0xff) {
      offset += 1;
      if (offset >= source.length) throw new Error('truncated JPEG marker');
    }
    const marker = source[offset];
    offset += 1;
    if (marker === 0xd9 || marker === 0xda) break;
    if (offset + 2 > source.length) throw new Error('truncated JPEG segment');
    const length = source.readUInt16BE(offset);
    if (length < 2 || offset + length > source.length) throw new Error('truncated JPEG segment');
    if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker)) {
      if (length < 8) throw new Error('truncated JPEG start of frame');
      const components = source[offset + 7];
      const colorType = { 1: 'gray', 3: 'rgb', 4: 'cmyk' }[components];
      if (!colorType) throw new Error('unsupported JPEG component count');
      return { format: 'jpeg', width: source.readUInt16BE(offset + 5), height: source.readUInt16BE(offset + 3), alpha: false, colorType };
    }
    offset += length;
  }
  throw new Error('JPEG start of frame marker not found');
}

function inspectWebp(source) {
  if (source.length < 21) throw new Error('truncated WebP chunk');
  const chunk = source.toString('ascii', 12, 16);
  const chunkLength = source.readUInt32LE(16);
  if (source.length < 20 + chunkLength) throw new Error('truncated WebP chunk');
  if (chunk === 'VP8X') {
    if (chunkLength !== 10) throw new Error('malformed VP8X chunk');
    const alpha = (source[20] & 0x10) !== 0;
    return { format: 'webp', width: 1 + source.readUIntLE(24, 3), height: 1 + source.readUIntLE(27, 3), alpha, colorType: alpha ? 'rgba' : 'rgb' };
  }
  if (chunk === 'VP8 ') {
    if (chunkLength < 10 || source.length < 30) throw new Error('truncated WebP chunk');
    if (source[23] !== 0x9d || source[24] !== 0x01 || source[25] !== 0x2a) throw new Error('malformed WebP frame header');
    return { format: 'webp', width: source.readUInt16LE(26) & 0x3fff, height: source.readUInt16LE(28) & 0x3fff, alpha: false, colorType: 'rgb' };
  }
  if (chunk === 'VP8L') {
    if (chunkLength < 5 || source[20] !== 0x2f) throw new Error('malformed VP8L chunk');
    const bits = source.readUInt32LE(21);
    const alpha = (source[24] & 0x10) !== 0;
    return { format: 'webp', width: (bits & 0x3fff) + 1, height: ((bits >> 14) & 0x3fff) + 1, alpha, colorType: alpha ? 'rgba' : 'rgb' };
  }
  throw new Error('unsupported WebP chunk');
}

function readArg(argv) {
  if (argv.length !== 2 || argv[0] !== '--input' || !argv[1]) throw new Error('usage: image-info --input FILE');
  return argv[1];
}
