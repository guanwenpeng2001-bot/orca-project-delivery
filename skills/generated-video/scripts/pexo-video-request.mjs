import { readFileSync } from 'node:fs';

const args = readArgs(process.argv.slice(2));
const key = process.env.PEXO_API_KEY ?? '';
if (!key) {
  respond(2, { error: 'missing-key', networkCalled: false });
}
const base = (process.env.PEXO_BASE_URL || 'https://pexo.ai').replace(/\/$/, '');
const submitted = JSON.parse(readFileSync(args.request, 'utf8'));
const request = {
  method: 'POST',
  url: `${base}/api/chat`,
  headers: { 'X-API-Key': key, 'Content-Type': 'application/json' },
  body: {
    project_id: submitted.project_id,
    user_visible: true,
    native_inputs: submitted.native_inputs,
  },
};
const fixture = JSON.parse(readFileSync(args.fixture, 'utf8'));
if (fixture.timeout) {
  respond(4, { request, error: 'timeout', networkCalled: false });
}
if (fixture.status !== 200) {
  respond(3, { request, provider: { status: fixture.status }, networkCalled: false });
}
respond(0, { request, acknowledgement: fixture.body, networkCalled: false });

function readArgs(argv) {
  const values = {};
  for (let index = 0; index < argv.length; index += 2) {
    values[argv[index].replace(/^--/, '')] = argv[index + 1];
  }
  for (const name of ['request', 'fixture']) {
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
