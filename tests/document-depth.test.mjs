import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const root = dirname(fileURLToPath(import.meta.url));
const fixture = join(root, 'fixtures/capability/document-blocks.json');
const script = join(root, '../skills/document-production/scripts/markdown-document.mjs');

function render(source) {
  const directory = mkdtempSync(join(tmpdir(), 'document-depth-'));
  const input = join(directory, 'source.json');
  const output = join(directory, 'notes.md');
  writeFileSync(input, JSON.stringify(source));
  const result = spawnSync(process.execPath, [script, '--input', input, '--output', output], { encoding: 'utf8' });
  return { result, output, directory };
}

const source = JSON.parse(readFileSync(fixture, 'utf8'));

test('the shared document-blocks fixture renders the bounded blocks', () => {
  const { result, output } = render(source);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(
    readFileSync(output, 'utf8').trim(),
    [
      '# Harbor notes',
      '',
      '## Berth plan',
      '',
      'Draft stays at 12.4 m through Friday.',
      '',
      '1. Sound the basin',
      '2. Log the tide',
      '',
      '- Keep one fact per bullet',
      '',
      '| Berth | Draft m |',
      '| --- | --- |',
      '| North | 12.4 |',
      '| South | 9.8 |',
    ].join('\n'),
  );
});

test('paragraph, heading, ordered list and table render as real Markdown', () => {
  const { result, output } = render(source);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(
    readFileSync(output, 'utf8').trim(),
    [
      '# Harbor notes',
      '',
      '## Berth plan',
      '',
      'Draft stays at 12.4 m through Friday.',
      '',
      '1. Sound the basin',
      '2. Log the tide',
      '',
      '- Keep one fact per bullet',
      '',
      '| Berth | Draft m |',
      '| --- | --- |',
      '| North | 12.4 |',
      '| South | 9.8 |',
    ].join('\n'),
  );
});

test('old title and bullets schema stays an unordered list', () => {
  const { result, output } = render({ title: 'Harbor notes', blocks: [{ type: 'bullets', items: ['Keep one fact per bullet'] }] });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(readFileSync(output, 'utf8').trim(), '# Harbor notes\n\n- Keep one fact per bullet');
});

test('a table cell holding formula-like text stays literal', () => {
  const { result, output } = render({ title: 'Notes', blocks: [{ type: 'table', columns: ['Expr'], rows: [['=SUM(A1:A2)']] }] });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(readFileSync(output, 'utf8').trim(), '# Notes\n\n| Expr |\n| --- |\n| =SUM(A1:A2) |');
});

test('pipe and newline characters in cells are escaped, not split', () => {
  const { result, output } = render({ title: 'Notes', blocks: [{ type: 'table', columns: ['A|B'], rows: [['one\ntwo']] }] });
  assert.equal(result.status, 0, result.stderr);
  const escapedPipe = '# Notes\n\n| A' + '\\' + '|B |\n| --- |\n| one two |';
  assert.equal(readFileSync(output, 'utf8').trim(), escapedPipe);
});

test('a literal backslash in a cell is escaped so it cannot escape the closing pipe', () => {
  const { result, output } = render({ title: 'Notes', blocks: [{ type: 'table', columns: ['A', 'B'], rows: [['ends\\', 'a\\|b']] }] });
  assert.equal(result.status, 0, result.stderr);
  const slash = String.fromCharCode(92);
  const rendered = '# Notes\n\n| A | B |\n| --- | --- |\n| ends' + slash + slash + ' | a' + slash + slash + slash + '|b |';
  assert.equal(readFileSync(output, 'utf8').trim(), rendered);
});

test('a malformed table is rejected and leaves an existing file untouched', () => {
  const directory = mkdtempSync(join(tmpdir(), 'document-depth-'));
  const output = join(directory, 'notes.md');
  writeFileSync(output, 'existing document');
  const input = join(directory, 'source.json');
  writeFileSync(input, JSON.stringify({ title: 'Notes', blocks: [{ type: 'table', columns: ['A', 'B'], rows: [['only-one']] }] }));
  const result = spawnSync(process.execPath, [script, '--input', input, '--output', output], { encoding: 'utf8' });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /row 1 has 1 cells but 2 columns/);
  assert.equal(readFileSync(output, 'utf8'), 'existing document');
});

test('an unknown block type is rejected by name', () => {
  const { result, output } = render({ title: 'Notes', blocks: [{ type: 'chart', items: [] }] });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /unsupported block chart/);
  assert.equal(existsSync(output), false);
});
