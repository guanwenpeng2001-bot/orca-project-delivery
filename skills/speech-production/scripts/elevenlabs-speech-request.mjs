import { readFileSync, writeFileSync } from 'node:fs';

const args = readArgs(process.argv.slice(2));
const key = process.env.ELEVENLABS_API_KEY ?? '';
if (!key) {
  respond(2, { error: 'missing-key', networkCalled: false });
}
const submitted = JSON.parse(readFileSync(args.request, 'utf8'));
const format = submitted.output_format || 'mp3_44100_128';
const request = {
  method: 'POST',
  url: `https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(submitted.voice_id)}?output_format=${encodeURIComponent(format)}`,
  headers: { 'xi-api-key': key, 'Content-Type': 'application/json' },
  body: { text: submitted.text, model_id: submitted.model_id },
};
const fixture = JSON.parse(readFileSync(args.fixture, 'utf8'));
if (fixture.status !== 200) {
  respond(3, { request, provider: { status: fixture.status }, networkCalled: false });
}
writeFileSync(args.output, Buffer.from(fixture.bodyBase64, 'base64'));
respond(0, { request, output: args.output, networkCalled: false });

function readArgs(argv) {
  const values = {};
  for (let index = 0; index < argv.length; index += 2) {
    values[argv[index].replace(/^--/, '')] = argv[index + 1];
  }
  for (const name of ['request', 'output', 'fixture']) {
    if (!values[name]) {
      process.stderr.write(`missing --${name}\n`);
      process.exit(1);
    }
  }
  return values;
}

function respond(status, report) {
  process.stdout.write(`${JSON.stringify(report)}\n`);
  process.exit(status);
}
