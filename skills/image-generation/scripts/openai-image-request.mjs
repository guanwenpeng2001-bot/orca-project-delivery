import { readFileSync, writeFileSync } from 'node:fs';

const args = readArgs(process.argv.slice(2));
const key = process.env.OPENAI_API_KEY ?? '';
if (!key) {
  respond(2, { error: 'missing-key', networkCalled: false });
}

const requestBody = JSON.parse(readFileSync(args.request, 'utf8'));
delete requestBody.response_format;
const request = {
  method: 'POST',
  url: 'https://api.openai.com/v1/images/generations',
  headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
  body: requestBody,
};
const fixture = JSON.parse(readFileSync(args.fixture, 'utf8'));
if (fixture.status !== 200) {
  respond(3, { request, provider: { status: fixture.status, code: fixture.body?.error?.code ?? null }, networkCalled: false });
}
const encoded = fixture.body?.data?.[0]?.b64_json;
if (!encoded) {
  respond(3, { request, provider: { status: fixture.status, code: 'missing-image' }, networkCalled: false });
}
writeFileSync(args.output, Buffer.from(encoded, 'base64'));
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
