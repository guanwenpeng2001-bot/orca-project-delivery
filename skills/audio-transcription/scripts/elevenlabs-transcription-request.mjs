import { readFileSync } from 'node:fs';
import path from 'node:path';
import { CapabilityError, cli, execute, jsonResponse, readJson, requireValue } from '../../../scripts/capability-runtime.mjs';

export function run(args, options = {}) {
  return execute(args, options, 'ELEVENLABS_API_KEY', async ({ key, call }) => {
    requireValue(args.output, 'output');
    const submitted = readJson(args.request);
    const model = requireValue(submitted.model_id, 'model-id');
    const audio = readFileSync(requireValue(args.audio, 'audio'));
    if (!audio.length) throw new CapabilityError(1, 'empty-audio');
    const body = new FormData();
    body.set('model_id', model);
    body.set('file', new Blob([audio], { type: 'application/octet-stream' }), path.basename(args.audio));
    const response = await call('https://api.elevenlabs.io/v1/speech-to-text', {
      method: 'POST', headers: { 'xi-api-key': key }, body,
    }, { parts: ['model_id', 'file'], model_id: model, filename: path.basename(args.audio) });
    const data = await jsonResponse(response);
    if (typeof data?.text !== 'string' || !Array.isArray(data.words) || data.words.some((word) => typeof word?.text !== 'string' || !Number.isFinite(word.start) || !Number.isFinite(word.end) || word.start < 0 || word.end < word.start)) throw new CapabilityError(3, 'malformed-result');
    return { bytes: Buffer.from(`${JSON.stringify({ text: data.text, words: data.words })}\n`) };
  });
}
cli(import.meta.url, run);
