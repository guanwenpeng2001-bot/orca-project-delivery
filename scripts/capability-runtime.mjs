import { readFileSync, writeFileSync, renameSync, rmSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { pathToFileURL } from 'node:url';

export class CapabilityError extends Error {
  constructor(exitCode, error, details = {}) { super(error); Object.assign(this, { exitCode, error, details }); }
}
export function requireValue(value, name) {
  if (typeof value !== 'string' || !value.trim()) throw new CapabilityError(1, `missing-${name}`);
  return value;
}
export function readJson(file) { return JSON.parse(readFileSync(requireValue(file, 'request'), 'utf8')); }
export function saveOutput(file, bytes) {
  requireValue(file, 'output');
  const temporary = `${file}.${randomUUID()}.part`;
  try { writeFileSync(temporary, bytes, { flag: 'wx' }); renameSync(temporary, file); }
  finally { rmSync(temporary, { force: true }); }
}
export function decodeBase64(value) {
  if (typeof value !== 'string' || !value.length || value.length % 4 || !/^[A-Za-z0-9+/]*={0,2}$/.test(value)) throw new CapabilityError(3, 'malformed-result');
  const bytes = Buffer.from(value, 'base64');
  if (!bytes.length || bytes.toString('base64') !== value) throw new CapabilityError(3, 'malformed-result');
  return bytes;
}
export async function jsonResponse(response) {
  try { return await response.json(); } catch { throw new CapabilityError(3, 'malformed-result'); }
}
export async function binaryResponse(response, contentType) {
  if (!contentType.test(response.headers.get('content-type') || '')) throw new CapabilityError(3, 'unexpected-content-type');
  let bytes;
  try { bytes = Buffer.from(await response.arrayBuffer()); }
  catch { throw new CapabilityError(3, 'response-read-failure'); }
  if (!bytes.length) throw new CapabilityError(3, 'empty-result');
  return bytes;
}
function fixtureTransport(file) {
  const fixture = readJson(file);
  const responses = fixture.responses || [fixture];
  let index = 0;
  return async () => {
    const item = responses[index++];
    if (!item) throw new CapabilityError(3, 'fixture-exhausted');
    if (item.timeout) throw new CapabilityError(4, 'timeout');
    return new Response(item.bodyBase64 ? decodeBase64(item.bodyBase64) : item.text ?? JSON.stringify(item.body), {
      status: item.status, headers: item.headers || { 'content-type': item.bodyBase64 ? 'audio/mpeg' : 'application/json' },
    });
  };
}
export async function execute(args, options, keyName, operation) {
  const env = options.env ?? process.env;
  let networkCalled = false;
  let requestReport;
  let timer;
  const controller = new AbortController();
  try {
    if (args.online && args.fixture) throw new CapabilityError(1, 'conflicting-modes');
    if (!args.fixture && (!args.online || env.CAPABILITY_ONLINE_PROVIDERS_ENABLED !== 'true')) throw new CapabilityError(2, 'online-disabled');
    const key = args.fixture ? 'synthetic-fixture-key' : env[keyName];
    if (!key) throw new CapabilityError(2, 'missing-key');
    const timeout = Number(args['timeout-ms'] ?? 60000);
    if (!Number.isSafeInteger(timeout) || timeout < 1 || timeout > 2147483647) throw new CapabilityError(1, 'invalid-timeout');
    const transport = args.fixture ? fixtureTransport(args.fixture) : options.fetchImpl ?? globalThis.fetch;
    const call = async (url, init = {}, bodyReport) => {
      if (controller.signal.aborted) throw new CapabilityError(4, 'timeout');
      const request = new Request(url, { ...init, signal: controller.signal, redirect: 'error' });
      const headers = Object.fromEntries(request.headers);
      if (headers.authorization) { headers.Authorization = 'Bearer [REDACTED]'; delete headers.authorization; }
      if (headers['xi-api-key']) headers['xi-api-key'] = '[REDACTED]';
      if (!requestReport || bodyReport) requestReport = { method: request.method, url: request.url, headers, ...(bodyReport ? { body: bodyReport } : {}) };
      if (!args.fixture) networkCalled = true;
      let response;
      try { response = await transport(request); }
      catch (error) {
        if (error instanceof CapabilityError) throw error;
        throw new CapabilityError(controller.signal.aborted ? 4 : 3, controller.signal.aborted ? 'timeout' : 'transport-failure');
      }
      if (!response.ok) {
        let code = null;
        try { const body = await response.json(); code = body?.error?.code ?? null; } catch {}
        throw new CapabilityError(3, 'http-failure', { provider: { status: response.status, code } });
      }
      return response;
    };
    const deadline = new Promise((_, reject) => {
      timer = setTimeout(() => { controller.abort(); reject(new CapabilityError(4, 'timeout')); }, timeout);
    });
    const result = await Promise.race([operation({ key, env, call, signal: controller.signal }), deadline]);
    if (result.bytes) {
      saveOutput(args.output, result.bytes);
      delete result.bytes;
      result.output = args.output;
    }
    return { exitCode: result.exitCode ?? 0, ...result, request: requestReport, networkCalled };
  } catch (error) {
    if (error instanceof CapabilityError) return { exitCode: error.exitCode, error: error.error, ...error.details, request: requestReport, networkCalled };
    return { exitCode: 1, error: 'invalid-input-or-filesystem', request: requestReport, networkCalled };
  } finally { clearTimeout(timer); controller.abort(); }
}
export function cli(moduleUrl, run) {
  if (!process.argv[1] || moduleUrl !== pathToFileURL(process.argv[1]).href) return;
  const args = {};
  try {
    for (let index = 2; index < process.argv.length; index++) {
      const name = process.argv[index];
      if (!/^--[a-z-]+$/.test(name) || name.slice(2) in args) throw new Error();
      args[name.slice(2)] = name === '--online' ? true : requireValue(process.argv[++index], name.slice(2));
    }
  } catch { process.stdout.write('{"error":"invalid-arguments","networkCalled":false}\n'); process.exitCode = 1; return; }
  run(args).then(({ exitCode, ...report }) => { process.stdout.write(`${JSON.stringify(report)}\n`); process.exitCode = exitCode; });
}
