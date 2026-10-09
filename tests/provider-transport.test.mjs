import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { run as image } from '../skills/image-generation/scripts/openai-image-request.mjs';
import { run as speech } from '../skills/speech-production/scripts/elevenlabs-speech-request.mjs';
import { run as transcript } from '../skills/audio-transcription/scripts/elevenlabs-transcription-request.mjs';
import { run as video } from '../skills/generated-video/scripts/pexo-video-request.mjs';

const fixtures = path.join(import.meta.dirname, 'fixtures/capability');
const env = { CAPABILITY_ONLINE_PROVIDERS_ENABLED: 'true', OPENAI_API_KEY: 'synthetic-key', ELEVENLABS_API_KEY: 'synthetic-key', PEXO_API_KEY: 'synthetic-key' };
const json = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
const png = JSON.parse(readFileSync(path.join(fixtures, 'openai-image-success.json'))).body;
const words = { text: 'Harbor', words: [{ text: 'Harbor', start: 0, end: 0.5 }] };
const providers = [
  { name: 'image', run: image, request: 'openai-image-request.json', response: () => json(png) },
  { name: 'speech', run: speech, request: 'elevenlabs-speech-request.json', response: () => new Response(Buffer.from('ID3synthetic-audio'), { headers: { 'content-type': 'audio/mpeg' } }) },
  { name: 'transcript', run: transcript, request: 'elevenlabs-transcription-request.json', response: () => json(words) },
  { name: 'video', run: video, request: 'pexo-video-request.json', response: () => json({ executionStatus: 'IDLE', serviceStatus: 'IDLE' }) },
];
async function temporary(action) {
  const directory = mkdtempSync(path.join(tmpdir(), 'provider-transport-'));
  try { await action(directory); } finally { rmSync(directory, { recursive: true, force: true }); }
}
function argsFor(provider, directory) {
  const audio = path.join(directory, 'source.wav');
  const wave = Buffer.alloc(46); wave.write('RIFF'); wave.writeUInt32LE(38, 4); wave.write('WAVEfmt ', 8); wave.writeUInt32LE(16, 16); wave.writeUInt16LE(1, 20); wave.writeUInt16LE(1, 22); wave.writeUInt32LE(16000, 24); wave.writeUInt32LE(32000, 28); wave.writeUInt16LE(2, 32); wave.writeUInt16LE(16, 34); wave.write('data', 36); wave.writeUInt32LE(2, 40);
  writeFileSync(audio, wave);
  return { online: true, request: path.join(fixtures, provider.request), output: path.join(directory, 'output'), audio };
}

for (const provider of providers) {
  test(`${provider.name}: both online gates and auth are enforced before transport`, () => temporary(async (directory) => {
    const args = argsFor(provider, directory);
    const fetchImpl = () => assert.fail('disabled or unconfigured operation reached transport');
    for (const [settings, environment, error] of [[{ ...args, online: false }, env, 'online-disabled'], [args, { ...env, CAPABILITY_ONLINE_PROVIDERS_ENABLED: 'false' }, 'online-disabled'], [args, { CAPABILITY_ONLINE_PROVIDERS_ENABLED: 'true' }, 'missing-key']]) {
      const report = await provider.run(settings, { env: environment, fetchImpl });
      assert.equal(report.exitCode, 2); assert.equal(report.error, error); assert.equal(report.networkCalled, false); assert.equal(existsSync(args.output), false);
    }
  }));
  test(`${provider.name}: real executor preserves HTTP error and leaves existing output alone`, () => temporary(async (directory) => {
    const args = argsFor(provider, directory); writeFileSync(args.output, 'keep');
    const report = await provider.run(args, { env, fetchImpl: async () => json({ error: { code: 'denied' } }, 403) });
    assert.equal(report.exitCode, 3); assert.deepEqual(report.provider, { status: 403, code: 'denied' }); assert.equal(report.networkCalled, true);
    assert.equal(readFileSync(args.output, 'utf8'), 'keep'); assert.equal(JSON.stringify(report).includes('synthetic-key'), false);
  }));
  test(`${provider.name}: transport timeout aborts and writes no output`, () => temporary(async (directory) => {
    const args = { ...argsFor(provider, directory), 'timeout-ms': 10 };
    let signal;
    const report = await provider.run(args, { env, fetchImpl: (request) => { signal = request.signal; return new Promise(() => {}); } });
    assert.equal(report.exitCode, 4); assert.equal(report.error, 'timeout'); assert.equal(signal.aborted, true); assert.equal(existsSync(args.output), false);
    assert.equal(readdirSync(directory).some((name) => name.endsWith('.part')), false);
  }));
  test(`${provider.name}: malformed response fails without saving`, () => temporary(async (directory) => {
    const args = argsFor(provider, directory);
    const report = await provider.run(args, { env, fetchImpl: async () => json({ unexpected: true }) });
    assert.equal(report.exitCode, 3); assert.equal(existsSync(args.output), false);
  }));
  test(`${provider.name}: network failure is sanitized`, () => temporary(async (directory) => {
    const args = argsFor(provider, directory);
    const report = await provider.run(args, { env, fetchImpl: async () => { throw new Error('synthetic-key connection reset'); } });
    assert.equal(report.exitCode, 3); assert.equal(report.error, 'transport-failure'); assert.equal(JSON.stringify(report).includes('synthetic-key'), false);
  }));
}

test('OpenAI executor sends configured model and saves decoded PNG', () => temporary(async (directory) => {
  const args = argsFor(providers[0], directory);
  const report = await image(args, { env: { ...env, OPENAI_IMAGE_MODEL: 'configured-image-model' }, fetchImpl: async (request) => {
    assert.equal(request.url, 'https://api.openai.com/v1/images/generations'); assert.equal(request.method, 'POST');
    assert.equal(request.headers.get('authorization'), 'Bearer synthetic-key');
    const body = await request.json(); assert.equal(body.model, 'configured-image-model'); assert.equal(body.response_format, undefined);
    return json(png);
  } });
  assert.equal(report.exitCode, 0); assert.equal(report.networkCalled, true); assert.deepEqual(readFileSync(args.output), Buffer.from(png.data[0].b64_json, 'base64'));
}));

test('TTS executor saves raw audio response without treating it as JSON', () => temporary(async (directory) => {
  const args = argsFor(providers[1], directory); const audio = Buffer.from('ID3synthetic-audio');
  const report = await speech(args, { env, fetchImpl: async (request) => {
    assert.equal(request.headers.get('xi-api-key'), 'synthetic-key'); assert.equal((await request.json()).text, 'Harbor closed at dusk.');
    return new Response(audio, { headers: { 'content-type': 'audio/mpeg' } });
  } });
  assert.equal(report.exitCode, 0); assert.deepEqual(readFileSync(args.output), audio);
}));

test('STT executor serializes actual multipart boundary, audio bytes, and model', () => temporary(async (directory) => {
  const args = argsFor(providers[2], directory);
  const report = await transcript(args, { env, fetchImpl: async (request) => {
    assert.match(request.headers.get('content-type'), /^multipart\/form-data; boundary=/);
    const body = await request.formData(); assert.deepEqual([...body.keys()], ['model_id', 'file']); assert.equal(body.get('model_id'), 'scribe_v2');
    assert.equal(body.get('file').name, 'source.wav'); assert.deepEqual(Buffer.from(await body.get('file').arrayBuffer()), readFileSync(args.audio));
    return json(words);
  } });
  assert.equal(report.exitCode, 0); assert.deepEqual(JSON.parse(readFileSync(args.output)), words);
}));

test('Pexo executor confirms the SSE opening marker across chunks and cancels stream', () => temporary(async (directory) => {
  const args = argsFor(providers[3], directory); let calls = 0; let cancelled = false;
  const report = await video(args, { env, now: () => 1234567890000, fetchImpl: async (request) => {
    assert.equal(request.headers.get('authorization'), 'Bearer synthetic-key'); calls++;
    if (calls === 1) { assert.match(request.url, /\/api\/biz\/projects\//); return json({ code: 0, data: { executionStatus: 'IDLE', serviceStatus: 'IDLE' } }); }
    assert.equal(request.url, 'https://pexo.ai/api/chat'); assert.equal(request.headers.get('accept'), 'text/event-stream');
    const body = await request.json(); assert.equal(body.timestamp, '1234567890000'); assert.deepEqual(body.billing_confirmation_policy, { mode: 'always' }); assert.equal(typeof body.native_inputs.text, 'string');
    return new Response(new ReadableStream({ start(controller) { controller.enqueue(Buffer.from(': stream op')); controller.enqueue(Buffer.from('ened\r\n\r\n')); }, cancel() { cancelled = true; } }), { headers: { 'content-type': 'text/event-stream' } });
  } });
  assert.equal(report.exitCode, 0); assert.equal(report.acknowledgement.status, 'submitted'); assert.equal(cancelled, true); assert.equal(existsSync(args.output), false);
}));

test('Pexo status reads newest user round and does not accept an older final video', () => temporary(async (directory) => {
  const args = { ...argsFor(providers[3], directory), action: 'status' }; let calls = 0;
  const report = await video(args, { env, fetchImpl: async () => ++calls === 1 ? json({ executionStatus: 'INTERRUPTED', serviceStatus: 'IDLE' }) : json({ messages: [
    { role: 'assistant', content: { event: 'message', data: { message: 'Choose preview' } } },
    { role: 'user', content: { native_inputs: { text: 'New video' } } },
    { role: 'assistant', content: { event: 'final_video', data: { final_video_id: 'old-asset' } } },
  ] }) });
  assert.equal(report.exitCode, 5); assert.equal(report.nextAction, 'RESPOND'); assert.equal(report.assetId, undefined);
}));

test('Pexo status paginates and extracts actual final_video_id', () => temporary(async (directory) => {
  const args = { ...argsFor(providers[3], directory), action: 'status' }; let calls = 0;
  const report = await video(args, { env, fetchImpl: async (request) => {
    calls++;
    if (calls === 1) return json({ executionStatus: 'INTERRUPTED', serviceStatus: 'IDLE' });
    if (calls === 2) return json({ messages: [{ role: 'assistant', content: { event: 'final_video', data: { final_video_id: 'final-asset' } } }], hasMore: true });
    assert.match(request.url, /page=2/); return json([{ role: 'user', content: { native_inputs: { text: 'Current brief' } } }]);
  } });
  assert.equal(report.exitCode, 0); assert.equal(report.nextAction, 'DELIVER'); assert.equal(report.assetId, 'final-asset'); assert.equal(existsSync(args.output), false);
}));

for (const [executionStatus, serviceStatus, nextAction, exitCode] of [['RUNNING', 'PROCESSING', 'WAIT', 5], ['RUNNING', 'IDLE', 'RECONNECT', 5], ['CONFIRM_REQUIRED', 'IDLE', 'CONFIRM', 5], ['FAILED', 'IDLE', 'FAILED', 3]]) {
  test(`Pexo status preserves ${nextAction} without automatically submitting`, () => temporary(async (directory) => {
    const args = { ...argsFor(providers[3], directory), action: 'status' };
    const report = await video(args, { env, fetchImpl: async (request) => { assert.equal(request.method, 'GET'); return json(request.url.includes('/history') ? [] : { executionStatus, serviceStatus }); } });
    assert.equal(report.exitCode, exitCode); assert.equal(report.nextAction, nextAction); assert.equal(existsSync(args.output), false);
  }));
}

test('Pexo download retrieves signed URL and saves video without forwarding authorization', () => temporary(async (directory) => {
  const args = { ...argsFor(providers[3], directory), action: 'download', request: path.join(directory, 'download.json') };
  writeFileSync(args.request, JSON.stringify({ project_id: 'project_example', asset_id: 'asset_example' }));
  const bytes = Buffer.from('00000018667479706d703432000000006d70343269736f6d', 'hex'); let calls = 0;
  const report = await video(args, { env, fetchImpl: async (request) => {
    calls++;
    if (calls === 1) return json({ assetStatus: 'READY' });
    if (calls === 2) { assert.match(request.url, /download-url\?remove_watermark=true$/); return json({ url: 'https://download.example/video.mp4?signature=synthetic', withWatermark: false }); }
    assert.equal(request.headers.get('authorization'), null); assert.equal(request.url, 'https://download.example/video.mp4?signature=synthetic');
    return new Response(bytes, { headers: { 'content-type': 'video/mp4' } });
  } });
  assert.equal(report.exitCode, 0); assert.equal(report.withWatermark, false); assert.deepEqual(readFileSync(args.output), bytes);
}));

for (const body of [{ text: 'bad', words: [{ text: 'bad', start: 2, end: 1 }] }, { text: 'bad', words: [{ text: 'bad', start: -1, end: 1 }] }]) {
  test('STT rejects malformed word timing', () => temporary(async (directory) => {
    const args = argsFor(providers[2], directory);
    const report = await transcript(args, { env, fetchImpl: async () => json(body) });
    assert.equal(report.exitCode, 3); assert.equal(existsSync(args.output), false);
  }));
}

test('fixture mode does not read credentials or transport even with online environment enabled', () => temporary(async (directory) => {
  const args = { ...argsFor(providers[0], directory), online: false, fixture: path.join(fixtures, 'openai-image-success.json') };
  const environment = { CAPABILITY_ONLINE_PROVIDERS_ENABLED: 'true', get OPENAI_API_KEY() { assert.fail('fixture read a credential'); } };
  const report = await image(args, { env: environment, fetchImpl: () => assert.fail('fixture reached transport') });
  assert.equal(report.exitCode, 0); assert.equal(report.networkCalled, false);
  const conflict = await image({ ...args, online: true }, { env: environment });
  assert.equal(conflict.exitCode, 1); assert.equal(conflict.error, 'conflicting-modes');
}));

test('Pexo does not resubmit a processing or billing-blocked project', () => temporary(async (directory) => {
  const args = argsFor(providers[3], directory);
  for (const [executionStatus, serviceStatus] of [['RUNNING', 'PROCESSING'], ['RUNNING', 'IDLE'], ['CONFIRM_REQUIRED', 'PROCESSING'], ['IDLE', 'PROCESSING']]) {
    const report = await video(args, { env, fetchImpl: async (request) => {
      assert.equal(request.method, 'GET'); return json({ executionStatus, serviceStatus });
    } });
    assert.equal(report.exitCode, 5); assert.equal(report.acknowledgement, undefined);
  }
}));

test('Pexo rejects non-production authenticated base without sending credentials', () => temporary(async (directory) => {
  const report = await video(argsFor(providers[3], directory), { env: { ...env, PEXO_BASE_URL: 'https://other.example' }, fetchImpl: () => assert.fail('untrusted base contacted') });
  assert.equal(report.exitCode, 2); assert.equal(report.networkCalled, false);
}));

for (const provider of [providers[1], providers[3]]) {
  test(provider.name + ': response stream failure is a provider failure without output', () => temporary(async (directory) => {
    const args = argsFor(provider, directory); let calls = 0;
    const report = await provider.run(args, { env, fetchImpl: async () => {
      if (provider.name === 'video' && ++calls === 1) return json({ executionStatus: 'IDLE', serviceStatus: 'IDLE' });
      return new Response(new ReadableStream({ start(controller) { controller.error(new Error('synthetic-key stream reset')); } }), { headers: { 'content-type': provider.name === 'video' ? 'text/event-stream' : 'audio/mpeg' } });
    } });
    assert.equal(report.exitCode, 3); assert.equal(JSON.stringify(report).includes('synthetic-key'), false); assert.equal(existsSync(args.output), false);
  }));
}

test('timeout covers slow response body and cannot create late output', () => temporary(async (directory) => {
  const args = { ...argsFor(providers[0], directory), 'timeout-ms': 10 }; let release;
  const report = await image(args, { env, fetchImpl: async () => new Response(new ReadableStream({ start(controller) { release = () => { controller.enqueue(Buffer.from(JSON.stringify(png))); controller.close(); }; } })) });
  assert.equal(report.exitCode, 4); release(); await new Promise((resolve) => setImmediate(resolve)); assert.equal(existsSync(args.output), false);
}));
