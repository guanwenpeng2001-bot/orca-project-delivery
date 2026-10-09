import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { crc32, deflateSync, inflateSync } from 'node:zlib';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';

const root = path.resolve(import.meta.dirname, '..');
const fixtures = path.join(root, 'tests/fixtures/capability');
const environment = { PATH: process.env.PATH, SystemRoot: process.env.SystemRoot, OPENAI_API_KEY: 'synthetic-key', ELEVENLABS_API_KEY: 'synthetic-key', PEXO_API_KEY: 'synthetic-key' };
function run(script, args, env = {}) {
  return spawnSync(process.execPath, [path.join(root, script), ...args], { encoding: 'utf8', env: { ...environment, ...env }, timeout: 10000 });
}
function temporary(action) {
  const directory = mkdtempSync(path.join(tmpdir(), 'capability-repair-'));
  try { return action(directory); } finally { rmSync(directory, { recursive: true, force: true }); }
}
function chunk(type, data) {
  const result = Buffer.alloc(data.length + 12);
  result.writeUInt32BE(data.length); result.write(type, 4); data.copy(result, 8);
  result.writeUInt32BE(crc32(result.subarray(4, -4)), result.length - 4);
  return result;
}
function png({ palette = false, level = 0 } = {}) {
  const header = Buffer.alloc(13); header.writeUInt32BE(64); header.writeUInt32BE(64, 4); header[8] = 8; header[9] = palette ? 3 : 6;
  const pixels = Buffer.alloc(64 * (1 + 64 * (palette ? 1 : 4)));
  return Buffer.concat([Buffer.from('89504e470d0a1a0a', 'hex'), chunk('IHDR', header), ...(palette ? [chunk('PLTE', Buffer.from([20, 90, 140])), chunk('tRNS', Buffer.from([255]))] : []), chunk('IDAT', deflateSync(pixels, { level })), chunk('tEXt', Buffer.from('author\0test')), chunk('IEND', Buffer.alloc(0))]);
}
function chunks(buffer) {
  const result = [];
  for (let offset = 8; offset < buffer.length;) {
    const length = buffer.readUInt32BE(offset);
    result.push({ type: buffer.toString('ascii', offset + 4, offset + 8), data: buffer.subarray(offset + 8, offset + 8 + length) }); offset += length + 12;
  }
  return result;
}

test('F1 Pexo uses Bearer authentication with credentials redacted', () => {
  const result = run('skills/generated-video/scripts/pexo-video-request.mjs', ['--request', path.join(fixtures, 'pexo-video-request.json'), '--fixture', path.join(fixtures, 'pexo-video-submitted.json')]);
  assert.equal(result.status, 0, result.stderr);
  const report = JSON.parse(result.stdout);
  assert.equal(report.request.headers.Authorization, 'Bearer [REDACTED]');
  assert.equal(report.request.headers['X-API-Key'], undefined);
});

test('F2 corrupt PNG CRC is rejected without an output', () => temporary((directory) => {
  const source = png(); source[29] ^= 1;
  const input = path.join(directory, 'input.png'); const output = path.join(directory, 'output.png'); writeFileSync(input, source);
  const result = run('skills/image-compression/scripts/png-compressor.mjs', ['--input', input, '--output', output]);
  assert.notEqual(result.status, 0, 'CRC corruption must fail'); assert.equal(existsSync(output), false);
}));

test('F3 no-gain PNG has explicit result and creates no artifact', () => temporary((directory) => {
  const input = path.join(directory, 'input.png'); const output = path.join(directory, 'output.png'); writeFileSync(input, png({ level: 9 }));
  const result = run('skills/image-compression/scripts/png-compressor.mjs', ['--input', input, '--output', output]);
  assert.equal(result.status, 0, result.stderr); assert.match(result.stdout, /"status":"no-gain"/); assert.equal(existsSync(output), false);
}));

test('F4 palette and ancillary chunk order and original scanlines survive compression', () => temporary((directory) => {
  const source = png({ palette: true }); const input = path.join(directory, 'input.png'); const output = path.join(directory, 'output.png'); writeFileSync(input, source);
  const result = run('skills/image-compression/scripts/png-compressor.mjs', ['--input', input, '--output', output]);
  assert.equal(result.status, 0, result.stderr);
  const original = chunks(source); const compressed = chunks(readFileSync(output));
  assert.deepEqual(compressed.map(({ type }) => type), original.map(({ type }) => type));
  assert.deepEqual(inflateSync(compressed.find(({ type }) => type === 'IDAT').data), inflateSync(original.find(({ type }) => type === 'IDAT').data));
}));

test('F5 and F6 transcription accepts real file/model_id and saves timed words', () => temporary((directory) => {
  const audio = path.join(directory, 'silence.wav'); writeFileSync(audio, Buffer.from('RIFFsynthetic-wave'));
  const fixture = path.join(directory, 'transcript.json'); const output = path.join(directory, 'output.json');
  const body = { text: 'Harbor', words: [{ text: 'Harbor', start: 0, end: 0.5, type: 'word' }] };
  writeFileSync(fixture, JSON.stringify({ status: 200, body }));
  const result = run('skills/audio-transcription/scripts/elevenlabs-transcription-request.mjs', ['--request', path.join(fixtures, 'elevenlabs-transcription-request.json'), '--audio', audio, '--output', output, '--fixture', fixture]);
  assert.equal(result.status, 0, result.stderr);
  const report = JSON.parse(result.stdout);
  assert.deepEqual(report.request.body.parts, ['model_id', 'file']);
  assert.deepEqual(JSON.parse(readFileSync(output)), body);
}));

test('F8 model configuration overrides request model', () => temporary((directory) => {
  const result = run('skills/image-generation/scripts/openai-image-request.mjs', ['--request', path.join(fixtures, 'openai-image-request.json'), '--output', path.join(directory, 'image.png'), '--fixture', path.join(fixtures, 'openai-image-success.json')], { OPENAI_IMAGE_MODEL: 'configured-image-model' });
  assert.equal(result.status, 0, result.stderr); assert.equal(JSON.parse(result.stdout).request.body.model, 'configured-image-model');
}));

test('malformed transcript response never writes a successful output', () => temporary((directory) => {
  const fixture = path.join(directory, 'invalid.json'); writeFileSync(fixture, '{"status":200,"body":{}}');
  const audio = path.join(directory, 'silence.wav'); writeFileSync(audio, 'synthetic'); const output = path.join(directory, 'output.json');
  const result = run('skills/audio-transcription/scripts/elevenlabs-transcription-request.mjs', ['--request', path.join(fixtures, 'elevenlabs-transcription-request.json'), '--audio', audio, '--output', output, '--fixture', fixture]);
  assert.equal(result.status, 3); assert.equal(existsSync(output), false);
}));

for (const source of [Buffer.from('89504e470d0a1a0a000000ff', 'hex'), png().subarray(0, -12), Buffer.concat([png(), Buffer.from('junk')])]) {
  test(`PNG rejects truncated or trailing structure (${source.length} bytes)`, () => temporary((directory) => {
    const input = path.join(directory, 'input.png'); const output = path.join(directory, 'output.png'); writeFileSync(input, source);
    const result = run('skills/image-compression/scripts/png-compressor.mjs', ['--input', input, '--output', output]);
    assert.notEqual(result.status, 0); assert.equal(existsSync(output), false);
  }));
}
