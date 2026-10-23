import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';

const root = path.resolve(import.meta.dirname, '..');
const read = (file) => readFileSync(path.join(root, file), 'utf8');
const blocks = (text) => [...text.matchAll(/^```powershell\r?\n([\s\S]*?)^```/gm)].map((match) => match[1]);
const languages = ['docs', 'docs/zh-CN'];
const environment = Object.fromEntries(Object.entries(process.env).filter(([name]) => /^(path|systemroot|windir|temp|tmp|pathext)$/i.test(name)));

// Frozen official release inventory; local extensions do not redefine this baseline.
const releaseSnapshot = {
  version: '3.1.1',
  roles: ['codebase-scout', 'technical-researcher', 'issue-investigator', 'requirements-analyst',
    'ui-designer', 'document-specialist', 'solution-planner', 'plan-adjudicator', 'software-architect',
    'software-implementer', 'code-reviewer', 'browser-test-engineer', 'security-reviewer',
    'release-verifier', 'merge-resolver', 'media-producer', 'game-designer', 'game-test-engineer'],
  skills: ['codebase-reconnaissance', 'technical-research', 'product-discovery', 'product-design',
    'requirements-analysis', 'solution-architecture', 'api-design', 'database-design',
    'implementation-planning', 'test-driven-development', 'systematic-debugging', 'code-review',
    'security-review', 'performance-review', 'integration-verification', 'merge-conflict-resolution',
    'frontend-visual-design', 'browser-e2e', 'accessibility-audit', 'postgres-practices', 'observability',
    'ci-pipeline', 'react-performance', 'react-composition', 'icon-assets', 'svg-logo-design',
    'web-assets', 'image-compression', 'image-generation', 'infographic-design', 'editorial-illustration',
    'visual-slide-deck', 'code-video-production', 'generated-video', 'speech-production',
    'audio-transcription', 'media-transcoding', 'document-production', 'design-system', 'domain-modeling',
    'localization', 'mcp-server-development', 'migration-upgrade', 'skill-authoring-evaluation',
    'subtitle-production', 'technical-diagrams',
    'game-design', 'game-economy-design', 'game-level-design', 'game-3c-design',
    'gameplay-programming', 'game-physics', 'game-content-pipeline', 'game-performance', 'game-multiplayer',
    'engine-urhox', 'engine-cocos-creator', 'engine-unity', 'engine-godot', 'engine-unreal', 'engine-web-canvas',
    'game-asset-pipeline', 'game-audio', 'game-testing-ladders', 'game-publishing', 'game-build-release',
    'game-live-ops', 'game-monetization-iaa', 'game-monetization-iap'],
  workflows: ['feature-development', 'bug-fix', 'refactor', 'audit', 'game-development'],
  deliverables: { roles: 18, professionalSkills: 69, workflows: 5 },
};

function temporaryDirectory(context, prefix) {
  const directory = mkdtempSync(path.join(tmpdir(), prefix));
  context.after(() => rmSync(directory, { recursive: true, force: true }));
  return directory;
}

function writeJson(directory, file, value) {
  writeFileSync(path.join(directory, file), JSON.stringify(value, null, 2) + '\n');
}

function releaseGuardFixture(context) {
  const fixture = temporaryDirectory(context, 'release-doc-guard-');
  for (const directory of ['routing', 'roles', 'workflows']) mkdirSync(path.join(fixture, directory));
  writeJson(fixture, 'routing/skill-catalog.json', { skills: releaseSnapshot.skills.map((id) => ({ id })) });
  writeJson(fixture, 'roles/catalog.json', { roles: releaseSnapshot.roles.map((id) => ({ id })) });
  writeJson(fixture, 'PACKAGE-MANIFEST.json', { version: releaseSnapshot.version, deliverables: releaseSnapshot.deliverables });
  for (const name of releaseSnapshot.workflows) writeFileSync(path.join(fixture, 'workflows', `${name}.md`), '');
  writeFileSync(path.join(fixture, 'VERSION'), releaseSnapshot.version + '\n');
  return fixture;
}

// Reuse production consistency and integrity checks. MetadataOnly avoids recursive Node discovery.
function consistencyAcceptance(directory) {
  const script = path.join(directory, 'scripts/verify-package.ps1').replaceAll("'", "''");
  return runPowerShell(`& '${script}' -MetadataOnly\nexit $LASTEXITCODE`, directory);
}

function assertConsistency(directory) {
  const manifest = JSON.parse(readFileSync(path.join(directory, 'PACKAGE-MANIFEST.json'), 'utf8'));
  const result = consistencyAcceptance(directory);
  assert.equal(result.status, 0, result.text);
  assert.match(result.text, /METADATA SUMMARY PASS=\d+ FAIL=0/);
  for (const [name, count] of Object.entries(manifest.deliverables)) {
    assert.ok(result.text.includes(`COUNT ${name}=${count}`), result.text);
  }
}

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

  test(`${language} current-version guard accepts 3.1.1 and rejects stale version/counts`, (context) => {
    const tutorial = blocks(read(`${language}/professional-capability-tutorial.md`));
    const countBlock = tutorial.find((block) => block.includes('$skills =') && block.includes('$roles ='));
    const versionBlock = tutorial.find((block) => block.includes('GUARD_PASSED'));
    assert.ok(countBlock && versionBlock);
    const script = countBlock + versionBlock;
    const fixture = releaseGuardFixture(context);
    const current = runPowerShell(script, fixture);
    assert.equal(current.status, 0, current.text);
    assert.match(current.text, /GUARD_PASSED skills=69 roles=18 version=3\.1\.1/);

    writeFileSync(path.join(fixture, 'VERSION'), '2.4.0\n');
    const stale = runPowerShell(script, fixture);
    assert.equal(stale.status, 1, stale.text);
    assert.match(stale.text, /Install the complete matching 3\.1\.1 package/);
    writeFileSync(path.join(fixture, 'VERSION'), '3.1.1\n');
    writeFileSync(path.join(fixture, 'routing/skill-catalog.json'), JSON.stringify({ skills: [] }));
    const wrongCount = runPowerShell(script, fixture);
    assert.equal(wrongCount.status, 1, wrongCount.text);
    assert.match(wrongCount.text, /Install the complete matching 3\.1\.1 package/);
  });
}

test('external Skill guides keep runnable configuration and recipe identical across languages', () => {
  const english = read('docs/external-skills.md');
  const chinese = read('docs/zh-CN/external-skills.md');
  assert.deepEqual(blocks(english), blocks(chinese));
  const json = (text) => JSON.parse(text.match(/^```json\r?\n([\s\S]*?)^```/m)[1]);
  assert.deepEqual(json(english), json(chinese));
});

test('official 3.1.1 snapshot retains exact release counts', (context) => {
  const fixture = releaseGuardFixture(context);
  const fixtureJson = (file) => JSON.parse(readFileSync(path.join(fixture, file), 'utf8'));
  assert.deepEqual(fixtureJson('PACKAGE-MANIFEST.json').deliverables, { roles: 18, professionalSkills: 69, workflows: 5 });
  assert.equal(fixtureJson('routing/skill-catalog.json').skills.length, 69);
  assert.equal(fixtureJson('roles/catalog.json').roles.length, 18);
  assert.equal(readdirSync(path.join(fixture, 'workflows')).length, 5);
});

test('current package catalogs, directories and manifest pass consistency acceptance', () => {
  assertConsistency(root);
});

test('public entry points describe the official 3.1.1 release', () => {
  for (const file of ['README.md', 'README.zh-CN.md']) {
    assert.match(read(file), /version-3\.1\.1-blue/);
    assert.match(read(file), /external-skills\.md/);
  }
  assert.match(read('CHANGELOG.md'), /^## 3\.1\.1 — 2026-10-23$/m);
  assert.match(read('CHANGELOG.md'), /^### 2\.4\.0 — professional skill depth$/m);
});

for (const language of languages) {
  test(`${language} documented Role/Skill extension passes consistency acceptance (19/70 from release baseline)`, (context) => {
    const fixture = temporaryDirectory(context, 'documented-extension-');
    cpSync(root, fixture, { recursive: true, filter: (source) => !['.git', '.dev-work'].includes(path.basename(source)) });
    const guide = read(`${language}/extending.md`);
    const markdown = [...guide.matchAll(/^```markdown\r?\n([\s\S]*?)^```/gm)].map((match) => match[1]);
    const json = [...guide.matchAll(/^```json\r?\n([\s\S]*?)^```/gm)].map((match) => JSON.parse(match[1]));
    const skill = json.find((entry) => entry.id === 'export-contract-check');
    const role = json.find((entry) => entry.id === 'export-reviewer');
    const route = json.find((entry) => entry.chain);
    assert.ok(skill && role && route);
    assert.equal(markdown.length, 2);
    const fixtureJson = (file) => JSON.parse(readFileSync(path.join(fixture, file), 'utf8'));
    const skills = fixtureJson('routing/skill-catalog.json');
    const roles = fixtureJson('roles/catalog.json');
    const isOfficialCount = roles.roles.length === 18 && skills.skills.length === 69;
    // Idempotent when full acceptance is itself running in the documented extended copy.
    skills.skills = [...skills.skills.filter((entry) => entry.id !== skill.id), skill];
    roles.roles = [...roles.roles.filter((entry) => entry.id !== role.id), role];
    writeJson(fixture, 'routing/skill-catalog.json', skills);
    writeJson(fixture, 'roles/catalog.json', roles);
    for (const [entry, body] of [[skill, markdown[0]], [role, markdown[1]]]) {
      mkdirSync(path.dirname(path.join(fixture, entry.path)), { recursive: true });
      writeFileSync(path.join(fixture, entry.path), body);
    }
    const routing = fixtureJson('routing/model-routing.json');
    routing.roles[role.id] = route;
    writeJson(fixture, 'routing/model-routing.json', routing);
    const selection = fixtureJson('routing/role-selection.json');
    selection.deliverableRoutes['export-contract-review'] = role.id;
    writeJson(fixture, 'routing/role-selection.json', selection);
    const manifest = fixtureJson('PACKAGE-MANIFEST.json');
    manifest.deliverables.roles = roles.roles.length;
    manifest.deliverables.professionalSkills = skills.skills.length;
    writeJson(fixture, 'PACKAGE-MANIFEST.json', manifest);
    if (isOfficialCount) {
      assert.deepEqual(manifest.deliverables, { roles: 19, professionalSkills: 70, workflows: 5 });
    }
    assertConsistency(fixture);
    // Exercise the former blockers from inside the extended package, without recursing into this test.
    const documentation = spawnSync(process.execPath, ['--test',
      '--test-name-pattern=current-version guard|official 3.1.1 snapshot|current package catalogs|release metadata',
      path.join(fixture, 'tests/external-skill-documentation.test.mjs')], {
      cwd: fixture, env: environment, encoding: 'utf8', timeout: 30000,
    });
    assert.ifError(documentation.error);
    assert.equal(documentation.status, 0, documentation.stdout + documentation.stderr);

    rmSync(path.join(fixture, skill.path));
    const missing = consistencyAcceptance(fixture);
    assert.equal(missing.status, 1, missing.text);
    assert.match(missing.text, /skill file missing:/);
  });
}

function markdownFiles(directory) {
  return readdirSync(path.join(root, directory), { withFileTypes: true }).flatMap((entry) => {
    const relative = path.join(directory, entry.name);
    return entry.isDirectory() ? markdownFiles(relative) : entry.name.endsWith('.md') ? [relative] : [];
  });
}

function withoutFences(text) {
  return text.replace(/^(`{3,}|~{3,})[^\n]*\n[\s\S]*?^\1\s*$/gm, '');
}

test('edited English and Chinese guides retain matching heading structure and optional Skills', () => {
  for (const name of ['usage', 'installation', 'professional-capabilities', 'extending']) {
    const levels = (text) => [...withoutFences(text).matchAll(/^(#{1,6})\s+/gm)].map((match) => match[1].length);
    assert.deepEqual(levels(read(`docs/${name}.md`)), levels(read(`docs/zh-CN/${name}.md`)), name);
  }
  const role = JSON.parse(read('roles/catalog.json')).roles.find((entry) => entry.id === 'document-specialist');
  for (const language of languages) {
    const row = read(`${language}/professional-capabilities.md`).split('\n').find((line) => line.startsWith('| `document-specialist` |'));
    assert.ok(row);
    for (const skill of role.optionalSkills) assert.ok(row.includes(`\`${skill}\``), `${language}: ${skill}`);
  }
});

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
