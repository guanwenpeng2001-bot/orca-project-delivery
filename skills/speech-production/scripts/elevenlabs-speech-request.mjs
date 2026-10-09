import { CapabilityError, binaryResponse, cli, execute, readJson, requireValue } from '../../../scripts/capability-runtime.mjs';

export function run(args, options = {}) {
  return execute(args, options, 'ELEVENLABS_API_KEY', async ({ key, call }) => {
    requireValue(args.output, 'output');
    const submitted = readJson(args.request);
    const voice = requireValue(submitted.voice_id, 'voice-id');
    const format = submitted.output_format || 'mp3_44100_128';
    const body = { text: requireValue(submitted.text, 'text'), model_id: requireValue(submitted.model_id, 'model-id') };
    const response = await call(`https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(voice)}?output_format=${encodeURIComponent(format)}`, {
      method: 'POST', headers: { 'xi-api-key': key, 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    }, body);
    const bytes = await binaryResponse(response, /^(audio\/|application\/octet-stream(?:;|$))/i);
    if (format.startsWith('mp3_') && bytes.toString('ascii', 0, 3) !== 'ID3' && !(bytes[0] === 255 && (bytes[1] & 224) === 224)) throw new CapabilityError(3, 'invalid-audio');
    return { bytes };
  });
}
cli(import.meta.url, run);
