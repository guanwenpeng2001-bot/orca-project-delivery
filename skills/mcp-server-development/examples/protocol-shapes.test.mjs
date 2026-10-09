import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const examples = path.dirname(fileURLToPath(import.meta.url));
const readJson = (name) => JSON.parse(readFileSync(path.join(examples, name), 'utf8'));

function assertExclusive(message) {
  const hasResult = Object.hasOwn(message, 'result');
  const hasError = Object.hasOwn(message, 'error');
  assert.equal(hasResult === hasError, false, 'result and error must be exclusive');
  assert.equal(message.jsonrpc, '2.0');
  assert.ok(Object.hasOwn(message, 'id'));
}

test('tools/list advertises a bounded schema and a structured result', () => {
  const listed = readJson('tools-list.json');
  assertExclusive(listed);
  const tool = listed.result.tools[0];
  assert.equal(tool.name, 'record_reading');
  assert.match(tool.name, /^[A-Za-z0-9._-]{1,128}$/);
  assert.equal(tool.inputSchema.type, 'object');
  assert.equal(tool.inputSchema.additionalProperties, false);
  assert.deepEqual(tool.inputSchema.required, ['sensor', 'celsius']);
  assert.equal(tool.inputSchema.properties.celsius.minimum, -89.2);
  assert.equal(tool.inputSchema.properties.celsius.maximum, 56.7);
  assert.deepEqual(tool.outputSchema.required, ['id', 'stored']);
});

test('a valid call echoes its structured result as text', () => {
  const { request, response } = readJson('call-valid.json');
  assert.equal(request.method, 'tools/call');
  assert.equal(request.params.arguments.celsius, 22.5);
  assertExclusive(response);
  assert.equal(response.id, request.id);
  assert.equal(response.result.isError, false);
  assert.equal(response.result.content[0].type, 'text');
  assert.deepEqual(JSON.parse(response.result.content[0].text), response.result.structuredContent);
  assert.equal(response.result.structuredContent.stored, true);
});

test('an unknown tool is a protocol error and carries no result', () => {
  const { response } = readJson('protocol-error.json');
  assertExclusive(response);
  assert.equal(Object.hasOwn(response, 'result'), false);
  assert.equal(response.error.code, -32602);
  assert.match(response.error.message, /^Unknown tool: /);
});

test('a value the tool refuses stays a tool result the caller can correct', () => {
  const { request, response } = readJson('tool-error.json');
  assert.equal(request.params.arguments.celsius, 400);
  assertExclusive(response);
  assert.equal(Object.hasOwn(response, 'error'), false);
  assert.equal(response.result.isError, true);
  assert.match(response.result.content[0].text, /between -89\.2 and 56\.7/);
});

test('a call without a tool name fails the request schema as a protocol error', () => {
  const { request, response } = readJson('malformed-request.json');
  assert.equal(Object.hasOwn(request.params, 'name'), false);
  assertExclusive(response);
  assert.equal(response.error.code, -32602);
  assert.equal(Object.hasOwn(response, 'result'), false);
});

test('stdio framing is one JSON-RPC message per line and nothing else on the stream', () => {
  const lines = readFileSync(path.join(examples, 'stdio-trace.txt'), 'utf8').trim().split(/\n/);
  assert.ok(lines.length >= 3);
  for (const line of lines) {
    assert.equal(line, line.trim());
    const message = JSON.parse(line);
    const isRequest = Object.hasOwn(message, 'method');
    assert.equal(isRequest || Object.hasOwn(message, 'result') !== Object.hasOwn(message, 'error'), true);
    assert.equal(message.jsonrpc, '2.0');
  }
});
