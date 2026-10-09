import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { inflateSync } from 'node:zlib';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const fixtureRoot = path.join(root, 'tests', 'fixtures', 'capability');

function runScript(relativePath, args, env = {}) {
  return spawnSync(process.execPath, [path.join(root, relativePath), ...args], {
    cwd: root,
    encoding: 'utf8',
    env: { PATH: process.env.PATH, SystemRoot: process.env.SystemRoot, ...env },
    timeout: 15000,
  });
}

function inflatePng(source) {
  let idat = Buffer.alloc(0);
  for (let offset = 8; offset < source.length;) {
    const length = source.readUInt32BE(offset);
    const type = source.subarray(offset + 4, offset + 8).toString('ascii');
    if (type === 'IDAT') idat = Buffer.concat([idat, source.subarray(offset + 8, offset + 8 + length)]);
    offset += 12 + length;
  }
  return inflateSync(idat);
}

function readFixture(name) {
  return JSON.parse(readFileSync(path.join(fixtureRoot, name), 'utf8'));
}

test('openai image request matches the pinned contract and writes decoded bytes', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'capability-image-'));
  try {
    const output = path.join(directory, 'otter.png');
    const result = runScript(
      'skills/image-generation/scripts/openai-image-request.mjs',
      ['--request', path.join(fixtureRoot, 'openai-image-request.json'), '--output', output, '--fixture', path.join(fixtureRoot, 'openai-image-success.json')],
      { OPENAI_API_KEY: 'synthetic-openai-key' },
    );
    assert.equal(result.status, 0, result.stderr);
    const report = JSON.parse(result.stdout);
    assert.equal(report.request.method, 'POST');
    assert.equal(report.request.url, 'https://api.openai.com/v1/images/generations');
    assert.equal(report.request.headers.Authorization, 'Bearer [REDACTED]');
    assert.equal(report.request.body.model, 'gpt-image-1.5');
    assert.equal(report.request.body.output_format, 'png');
    assert.equal(report.request.body.response_format, undefined);
    assert.equal(readFileSync(output).toString('hex'), readFixture('openai-image-success.json').expectedPngHex);
    assert.equal(report.networkCalled, false);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('openai image connector reports a missing key without building a callable request', () => {
  const result = runScript('skills/image-generation/scripts/openai-image-request.mjs', [
    '--request', path.join(fixtureRoot, 'openai-image-request.json'),
    '--output', path.join(tmpdir(), 'unused.png'),
    '--online',
  ], { OPENAI_API_KEY: '', CAPABILITY_ONLINE_PROVIDERS_ENABLED: 'true' });
  assert.equal(result.status, 2);
  assert.equal(JSON.parse(result.stdout).error, 'missing-key');
  assert.equal(JSON.parse(result.stdout).request, undefined);
});

test('openai image connector preserves provider failure status and does not write output', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'capability-image-fail-'));
  const output = path.join(directory, 'otter.png');
  try {
    const result = runScript(
      'skills/image-generation/scripts/openai-image-request.mjs',
      ['--request', path.join(fixtureRoot, 'openai-image-request.json'), '--output', output, '--fixture', path.join(fixtureRoot, 'openai-image-failure.json')],
      { OPENAI_API_KEY: 'synthetic-openai-key' },
    );
    assert.equal(result.status, 3, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout).provider, { status: 429, code: 'rate_limit_exceeded' });
    assert.throws(() => readFileSync(output));
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('pexo video submission is asynchronous and a timeout stays pending', () => {
  const submitted = runScript(
    'skills/generated-video/scripts/pexo-video-request.mjs',
    ['--request', path.join(fixtureRoot, 'pexo-video-request.json'), '--fixture', path.join(fixtureRoot, 'pexo-video-submitted.json')],
    { PEXO_API_KEY: 'synthetic-pexo-key' },
  );
  assert.equal(submitted.status, 0, submitted.stderr);
  const submission = JSON.parse(submitted.stdout);
  assert.equal(submission.request.url, 'https://pexo.ai/api/chat');
  assert.equal(submission.request.headers.Authorization, 'Bearer [REDACTED]');
  assert.equal(submission.acknowledgement.status, 'submitted');
  assert.equal(submission.networkCalled, false);

  const timedOut = runScript(
    'skills/generated-video/scripts/pexo-video-request.mjs',
    ['--request', path.join(fixtureRoot, 'pexo-video-request.json'), '--fixture', path.join(fixtureRoot, 'pexo-video-timeout.json')],
    { PEXO_API_KEY: 'synthetic-pexo-key' },
  );
  assert.equal(timedOut.status, 4);
  assert.equal(JSON.parse(timedOut.stdout).error, 'timeout');
  assert.equal(JSON.parse(timedOut.stdout).output, undefined);
});

test('elevenlabs speech and transcription requests stay offline and handle failure', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'capability-audio-'));
  try {
    const audio = path.join(directory, 'speech.mp3');
    const speech = runScript(
      'skills/speech-production/scripts/elevenlabs-speech-request.mjs',
      ['--request', path.join(fixtureRoot, 'elevenlabs-speech-request.json'), '--output', audio, '--fixture', path.join(fixtureRoot, 'elevenlabs-speech-success.json')],
      { ELEVENLABS_API_KEY: 'synthetic-elevenlabs-key' },
    );
    assert.equal(speech.status, 0, speech.stderr);
    const speechReport = JSON.parse(speech.stdout);
    assert.equal(speechReport.request.url, 'https://api.elevenlabs.io/v1/text-to-speech/voice_example?output_format=mp3_44100_128');
    assert.equal(speechReport.request.headers['xi-api-key'], '[REDACTED]');
    assert.equal(readFileSync(audio).toString('utf8'), 'ID3synthetic-audio');

    const transcript = path.join(directory, 'transcript.json');
    const transcription = runScript(
      'skills/audio-transcription/scripts/elevenlabs-transcription-request.mjs',
      ['--request', path.join(fixtureRoot, 'elevenlabs-transcription-request.json'), '--audio', audio, '--output', transcript, '--fixture', path.join(fixtureRoot, 'elevenlabs-transcription-failure.json')],
      { ELEVENLABS_API_KEY: 'synthetic-elevenlabs-key' },
    );
    assert.equal(transcription.status, 3);
    assert.equal(JSON.parse(transcription.stdout).provider.status, 422);
    assert.throws(() => readFileSync(transcript));
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('local asset, compression, document, and transcoding plans are deterministic', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'capability-local-'));
  try {
    const manifest = path.join(directory, 'manifest.json');
    const assets = runScript('skills/web-assets/scripts/web-asset-manifest.mjs', [
      '--name', 'Harbor', '--color', '#123456', '--output', manifest,
    ]);
    assert.equal(assets.status, 0, assets.stderr);
    assert.deepEqual(JSON.parse(readFileSync(manifest, 'utf8')).icons.map((icon) => icon.sizes), ['16x16', '32x32', '180x180', '192x192', '512x512']);

    const source = path.join(directory, 'source.png');
    const generated = runScript('skills/image-compression/scripts/png-compressor.mjs', ['--sample', source]);
    assert.equal(generated.status, 0, generated.stderr);
    const compressed = path.join(directory, 'sample.png');
    const compression = runScript('skills/image-compression/scripts/png-compressor.mjs', ['--input', source, '--output', compressed]);
    assert.equal(compression.status, 0, compression.stderr);
    assert.ok(readFileSync(compressed).length < readFileSync(source).length);
    assert.equal(readFileSync(compressed).subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    assert.equal(inflatePng(readFileSync(compressed)).equals(inflatePng(readFileSync(source))), true);

    const document = path.join(directory, 'notes.md');
    const rendered = runScript('skills/document-production/scripts/markdown-document.mjs', [
      '--input', path.join(fixtureRoot, 'document-input.json'), '--output', document,
    ]);
    assert.equal(rendered.status, 0, rendered.stderr);
    assert.match(readFileSync(document, 'utf8'), /^# Harbor notes\n\n- Keep one fact per bullet\n$/);

    const plan = runScript('skills/media-transcoding/scripts/ffmpeg-plan.mjs', [
      '--input', 'input.mov', '--output', 'output.mp4', '--width', '1280', '--height', '720', '--fps', '30',
    ]);
    assert.equal(plan.status, 0, plan.stderr);
    assert.deepEqual(JSON.parse(plan.stdout).argv, [
      'ffmpeg', '-i', 'input.mov', '-vf', 'scale=1280:720', '-r', '30',
      '-c:v', 'libx264', '-crf', '20', '-c:a', 'aac', '-movflags', '+faststart', 'output.mp4',
    ]);
    assert.equal(JSON.parse(plan.stdout).executed, false);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('provider example configuration is explicit and does not authorize a call', () => {
  const config = JSON.parse(readFileSync(path.join(root, 'templates', 'project-config.example.json'), 'utf8'));
  assert.equal(config.env.CAPABILITY_ONLINE_PROVIDERS_ENABLED, 'false');
  assert.equal(config.env.OPENAI_IMAGE_MODEL, 'gpt-image-1.5');
  const dotenv = readFileSync(path.join(root, '.env.example'), 'utf8');
  for (const name of ['OPENAI_API_KEY', 'PEXO_API_KEY', 'ELEVENLABS_API_KEY']) {
    assert.match(dotenv, new RegExp(`^${name}=$`, 'm'));
    assert.equal(dotenv.includes(`${name}=synthetic`), false);
  }
});
