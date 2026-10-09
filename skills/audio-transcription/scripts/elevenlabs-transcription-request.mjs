import { readFileSync, writeFileSync } from 'node:fs';

const args = readArgs(process.argv.slice(2));
const key = process.env.ELEVENLABS_API_KEY ?? '';
if (!key) {
  respond(2, { error: 'missing-key', networkCalled: false });
}
const submitted = JSON.parse(readFileSync(args.request, 'utf8'));
const request = {
  method: 'POST',
  url: 'https://api.elevenlabs.io/v1/speech-to-text',
  headers: { 'xi-api-key': key },
  body: { model_id: submitted.model_id, filename: submitted.filename },
};
const fixture = JSON.parse(readFileSync(args.fixture, 'utf8'));
if (fixture.status !== 200) {
  respond(3, { request, provider: { status: fixture.status }, networkCalled: false });
}
writeFileSync(args.output, `${JSON.stringify({ text: fixture.body.text, words: fixture.body.words })}\n`);
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
