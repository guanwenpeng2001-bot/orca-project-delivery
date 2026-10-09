import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const examples = path.dirname(fileURLToPath(import.meta.url));
const read = (name) => readFileSync(path.join(examples, name), 'utf8');

function viewBoxOf(source) {
  const match = source.match(/viewBox="([^"]+)"/);
  assert.ok(match, 'viewBox required');
  const [minX, minY, width, height] = match[1].split(/\s+/).map(Number);
  return { minX, minY, maxX: minX + width, maxY: minY + height };
}

function textElements(source) {
  return [...source.matchAll(/<text\b([^>]*)>([^<]*)<\/text>/g)].map((match) => {
    const readAttr = (name) => {
      const found = match[1].match(new RegExp(`${name}="([^"]+)"`));
      return found ? found[1] : undefined;
    };
    return {
      x: Number(readAttr('x')),
      y: Number(readAttr('y')),
      size: Number(readAttr('font-size')),
      anchor: readAttr('text-anchor') ?? 'start',
      fill: readAttr('fill'),
      text: match[2],
    };
  });
}

function contained(element, box) {
  const width = element.text.length * element.size * 0.6;
  const left = element.anchor === 'middle' ? element.x - width / 2 : element.x;
  const right = left + width;
  return left >= box.minX && right <= box.maxX && element.y >= box.minY && element.y <= box.maxY;
}

test('the sequence source names both peers and the version header', () => {
  const source = read('version-header.mmd');
  assert.match(source, /^sequenceDiagram/m);
  assert.match(source, /participant Client/);
  assert.match(source, /participant Server/);
  assert.match(source, /Accept-Version: 2/);
});

test('the maintained figure meets the semantic checks', () => {
  const source = read('version-header.svg');
  const box = viewBoxOf(source);
  assert.doesNotMatch(source, /<svg\b[^>]*\s(?:width|height)="/);
  assert.match(source, /<title>[^<]+<\/title>/);
  assert.match(source, /<desc>[^<]*Accept-Version[^<]*<\/desc>/);
  assert.equal((source.match(/<script\b/g) ?? []).length, 0);
  assert.equal((source.match(/<image\b/g) ?? []).length, 0);
  assert.doesNotMatch(source, /(?:href|src)="https?:/);
  const texts = textElements(source);
  assert.equal(texts.length, 3);
  for (const element of texts) {
    assert.ok(element.size >= 14, element.text);
    assert.equal(element.fill, 'currentColor');
    assert.equal(contained(element, box), true, element.text);
  }
});

test('the broken twin fails independently of being well-formed XML', () => {
  const source = read('version-header-broken.svg');
  const box = viewBoxOf(source);
  assert.match(source, /\swidth="640"/);
  assert.equal((source.match(/<desc>/g) ?? []).length, 0);
  assert.match(source, /<title>diagram<\/title>/);
  assert.match(source, /<image\b[^>]*https:/);
  const texts = textElements(source);
  assert.equal(texts.length, 1);
  assert.ok(texts[0].size < 12);
  assert.equal(contained(texts[0], box), false);
  assert.equal(texts[0].fill, '#888888');
  assert.match(source, /<path d="M70 62 H150"/);
});
