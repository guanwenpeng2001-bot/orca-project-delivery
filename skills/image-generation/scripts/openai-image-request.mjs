import { CapabilityError, cli, decodeBase64, execute, jsonResponse, readJson, requireValue } from '../../../scripts/capability-runtime.mjs';

export function run(args, options = {}) {
  return execute(args, options, 'OPENAI_API_KEY', async ({ key, env, call }) => {
    requireValue(args.output, 'output');
    const body = readJson(args.request);
    requireValue(body.prompt, 'prompt');
    body.model = env.OPENAI_IMAGE_MODEL || body.model || 'gpt-image-1.5';
    body.output_format ??= 'png';
    if (!['png', 'jpeg', 'webp'].includes(body.output_format) || (body.n !== undefined && body.n !== 1)) throw new CapabilityError(1, 'unsupported-image-options');
    delete body.response_format;
    const response = await call('https://api.openai.com/v1/images/generations', {
      method: 'POST', headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    }, body);
    const data = await jsonResponse(response);
    const bytes = decodeBase64(data?.data?.[0]?.b64_json);
    const valid = body.output_format === 'png' ? bytes.subarray(0, 8).toString('hex') === '89504e470d0a1a0a'
      : body.output_format === 'jpeg' ? bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255
        : bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP';
    if (!valid) throw new CapabilityError(3, 'invalid-image');
    return { bytes };
  });
}
cli(import.meta.url, run);
