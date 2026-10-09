import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const examples = path.dirname(fileURLToPath(import.meta.url));
const messages = JSON.parse(readFileSync(path.join(examples, 'messages.json'), 'utf8'));

function placeholders(message) {
  return [...new Set([...message.matchAll(/\{([a-zA-Z][\w]*)(?:,|\})/g)].map((match) => match[1]))].sort();
}

function pluralCategories(message) {
  const body = message.match(/\{count, plural, (.+)}$/);
  if (!body) return [];
  return [...body[1].matchAll(/(^|\s)(zero|one|two|few|many|other)\s+\{/g)].map((match) => match[2]);
}

test('source messages name placeholders and select plural categories', () => {
  const english = messages.locales.en['save.summary'];
  assert.deepEqual(placeholders(english), ['count', 'folder']);
  assert.deepEqual(pluralCategories(english), ['one', 'other']);
  assert.equal(english.includes('count === 1'), false);
});

test('the arabic message covers every category that locale needs', () => {
  const arabic = messages.locales.ar['save.summary'];
  assert.deepEqual(pluralCategories(arabic), ['zero', 'one', 'two', 'few', 'many', 'other']);
  assert.deepEqual(placeholders(arabic), ['count', 'folder']);
});

test('locale files agree on keys and placeholder sets', () => {
  const englishKeys = Object.keys(messages.locales.en).sort();
  const arabicKeys = Object.keys(messages.locales.ar).sort();
  assert.deepEqual(arabicKeys, englishKeys);
  for (const key of englishKeys) {
    assert.deepEqual(placeholders(messages.locales.ar[key]), placeholders(messages.locales.en[key]));
  }
});

test('a dropped placeholder fails parity and is not treated as a translation', () => {
  const broken = messages.broken.ar['save.summary'];
  const missing = placeholders(messages.locales.en['save.summary'])
    .filter((name) => !placeholders(broken).includes(name));
  assert.deepEqual(missing, ['folder']);
  assert.equal(pluralCategories(broken).includes('zero'), false);
});

test('pseudo-localization keeps the placeholder and marks expansion', () => {
  const pseudo = messages.pseudo['save.summary'];
  assert.equal(pseudo.startsWith('['), true);
  assert.equal(pseudo.endsWith(']'), true);
  assert.deepEqual(placeholders(pseudo), ['folder']);
  assert.match(pseudo, /[À-ÿĀ-ɏ]/);
});
