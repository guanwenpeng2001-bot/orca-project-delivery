import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';

const root = path.resolve(import.meta.dirname, '..');
const read = (file) => readFileSync(path.join(root, file), 'utf8');
const blocks = (text) => [...text.matchAll(/^```powershell\r?\n([\s\S]*?)^```/gm)].map((match) => match[1]);
const languages = ['docs', 'docs/zh-CN'];
const environment = Object.fromEntries(Object.entries(process.env).filter(([name]) => /^(path|systemroot|windir|temp|tmp|pathext)$/i.test(name)));

function runPowerShell(script, cwd = root) {
  const encoded = Buffer.from(`$ErrorActionPreference = 'Stop'\n${script}\nexit 0`, 'utf16le').toString('base64');
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-EncodedCommand', encoded], {
    cwd, env: environment, encoding: 'utf8', timeout: 60000,
  });
  assert.ifError(result.error);
  return { status: result.status, text: result.stdout + result.stderr };
}

for (const language of languages) {
  test(`${language} installed external Skill walkthrough executes unchanged`, () => {
    const recipe = blocks(read(`${language}/external-skills.md`));
    assert.equal(recipe.length, 1);
    const result = runPowerShell(recipe[0]);
    assert.equal(result.status, 0, result.text);
    assert.equal(result.text.match(/External sibling resource passed\./g)?.length, 2, result.text);
    assert.match(result.text, /External Skill walkthrough passed: both delivery modes, original resources, unchanged sources, named failure\./);
  });

  test(`${language} current-version guard accepts 2.5.0 and rejects stale version/counts`, (context) => {
    const tutorial = blocks(read(`${language}/professional-capability-tutorial.md`));
    const countBlock = tutorial.find((block) => block.includes('$skills =') && block.includes('$roles ='));
    const versionBlock = tutorial.find((block) => block.includes('GUARD_PASSED'));
    assert.ok(countBlock && versionBlock);
    const script = countBlock + versionBlock;
    const current = runPowerShell(script);
    assert.equal(current.status, 0, current.text);
    assert.match(current.text, /GUARD_PASSED skills=46 roles=16 version=2\.5\.0/);

    const fixture = mkdtempSync(path.join(tmpdir(), 'external-doc-guard-'));
    context.after(() => rmSync(fixture, { recursive: true, force: true }));
    for (const directory of ['routing', 'roles', 'workflows']) mkdirSync(path.join(fixture, directory));
    for (const file of ['routing/skill-catalog.json', 'roles/catalog.json', 'PACKAGE-MANIFEST.json']) {
      writeFileSync(path.join(fixture, file), read(file));
    }
    for (const name of ['feature-development', 'bug-fix', 'refactor', 'audit']) writeFileSync(path.join(fixture, 'workflows', `${name}.md`), '');
    writeFileSync(path.join(fixture, 'VERSION'), '2.4.0\n');
    const stale = runPowerShell(script, fixture);
    assert.equal(stale.status, 1, stale.text);
    assert.match(stale.text, /Install the complete matching 2\.5\.0 package/);
    writeFileSync(path.join(fixture, 'VERSION'), '2.5.0\n');
    writeFileSync(path.join(fixture, 'routing/skill-catalog.json'), JSON.stringify({ skills: [] }));
    const wrongCount = runPowerShell(script, fixture);
    assert.equal(wrongCount.status, 1, wrongCount.text);
    assert.match(wrongCount.text, /Install the complete matching 2\.5\.0 package/);
  });
}

test('external Skill guides keep runnable configuration and recipe identical across languages', () => {
  const english = read('docs/external-skills.md');
  const chinese = read('docs/zh-CN/external-skills.md');
  assert.deepEqual(blocks(english), blocks(chinese));
  const json = (text) => JSON.parse(text.match(/^```json\r?\n([\s\S]*?)^```/m)[1]);
  assert.deepEqual(json(english), json(chinese));
});

test('release metadata and public entry points agree on version and bundled counts', () => {
  const manifest = JSON.parse(read('PACKAGE-MANIFEST.json'));
  assert.equal(read('VERSION').trim(), '2.5.0');
  assert.equal(manifest.version, '2.5.0');
  assert.deepEqual(manifest.deliverables, { roles: 16, professionalSkills: 46, workflows: 4 });
  assert.equal(JSON.parse(read('routing/skill-catalog.json')).skills.length, 46);
  assert.equal(JSON.parse(read('roles/catalog.json')).roles.length, 16);
  assert.equal(readdirSync(path.join(root, 'workflows')).filter((file) => file.endsWith('.md')).length, 4);
  for (const file of ['README.md', 'README.zh-CN.md']) {
    assert.match(read(file), /version-2\.5\.0-blue/);
    assert.match(read(file), /external-skills\.md/);
  }
  assert.match(read('CHANGELOG.md'), /^## 2\.5\.0 — 2026-10-10$/m);
  assert.match(read('CHANGELOG.md'), /^### 2\.4\.0 — professional skill depth$/m);
});

function markdownFiles(directory) {
  return readdirSync(path.join(root, directory), { withFileTypes: true }).flatMap((entry) => {
    const relative = path.join(directory, entry.name);
    return entry.isDirectory() ? markdownFiles(relative) : entry.name.endsWith('.md') ? [relative] : [];
  });
}

function withoutFences(text) {
  return text.replace(/^(`{3,}|~{3,})[^\n]*\n[\s\S]*?^\1\s*$/gm, '');
}

function headingAnchors(text) {
  const counts = new Map();
  return new Set([...withoutFences(text).matchAll(/^#{1,6}\s+(.+)$/gm)].map((match) => {
    const slug = match[1].trim().replace(/<[^>]*>/g, '').replace(/[^\p{L}\p{N}\p{M}_\-\s]/gu, '').toLowerCase().replace(/\s/g, '-');
    const count = counts.get(slug) ?? 0;
    counts.set(slug, count + 1);
    return count ? `${slug}-${count}` : slug;
  }));
}

test('English and Chinese public documentation local links and heading anchors resolve', () => {
  const failures = [];
  for (const file of ['README.md', 'README.zh-CN.md', ...markdownFiles('docs'), ...markdownFiles('references')]) {
    const text = withoutFences(read(file));
    const localLinks = [...text.matchAll(/\[[^\]\n]*\]\(([^)\s]+)\)/g)].filter((match) => !/^[a-z][a-z\d+.-]*:/i.test(match[1]));
    for (const match of localLinks) {
      const target = match[1];
      const [relative, anchor] = target.split('#');
      const resolved = relative ? path.resolve(root, path.dirname(file), decodeURIComponent(relative)) : path.join(root, file);
      if (!existsSync(resolved)) failures.push(`${file}: missing ${target}`);
      else if (anchor && resolved.endsWith('.md') && !headingAnchors(readFileSync(resolved, 'utf8')).has(decodeURIComponent(anchor))) {
        failures.push(`${file}: missing anchor ${target}`);
      }
    }
  }
  assert.deepEqual(failures, []);
});
