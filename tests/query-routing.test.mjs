import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const packageRoot = fileURLToPath(new URL('../', import.meta.url));
const script = path.join(packageRoot, 'scripts/query-routing.ps1');
const routing = JSON.parse(readFileSync(new URL('../routing/model-routing.json', import.meta.url), 'utf8'));
const catalog = JSON.parse(readFileSync(new URL('../roles/catalog.json', import.meta.url), 'utf8'));
const policyNames = ['escalate', 'downgrade', 'suspend', 'userPinned', 'trivialTaskAdjustment', 'recording'];
const capabilitiesPath = '.dev-work/runtime/claude-capabilities.json';

function temporaryDirectory(t) {
  const directory = mkdtempSync(path.join(tmpdir(), 'query-routing-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  return directory;
}

function query(role, { entrypoint = script, cwd = packageRoot, projectRoot } = {}) {
  const args = ['-NoProfile', '-NonInteractive', '-File', entrypoint, '-Role', role];
  if (projectRoot) args.push('-ProjectRoot', projectRoot);
  const result = spawnSync('pwsh', args, { cwd, encoding: 'utf8', timeout: 15000 });
  assert.ifError(result.error);
  return result;
}

function expectedSlice(role) {
  return {
    roles: { [role]: routing.roles[role] },
    modelTiers: Object.fromEntries([...new Set(routing.roles[role].chain.map(({ tier }) => tier))]
      .map((tier) => [tier, routing.modelTiers[tier]])),
    policies: Object.fromEntries(policyNames.map((name) => [name, routing.policies[name]])),
    vocabulary: routing.vocabulary,
  };
}

for (const { id } of catalog.roles) {
  test(`returns an exact UTF-8 dispatch slice within 4KB for ${id}`, (t) => {
    const result = query(id, { cwd: temporaryDirectory(t) });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stderr, '');
    assert.deepEqual(JSON.parse(result.stdout), expectedSlice(id));
    assert.ok(Buffer.byteLength(result.stdout, 'utf8') <= 4096, `${id}: ${Buffer.byteLength(result.stdout)} bytes`);
    assert.notEqual(result.stdout.charCodeAt(0), 0xfeff, 'stdout must not have a BOM');
  });
}

for (const role of ['unknown-role', 'CODEBASE-SCOUT']) {
  test(`rejects unknown role ${role} with valid ids on stderr`, () => {
    const result = query(role);
    assert.notEqual(result.status, 0);
    assert.equal(result.stdout, '');
    assert.ok(result.stderr.includes(role), result.stderr);
    assert.match(result.stderr, /Unknown role/);
    for (const { id } of catalog.roles) assert.ok(result.stderr.includes(id), result.stderr);
  });
}

for (const missingFrom of ['routing', 'catalog']) {
  test(`rejects a role missing from ${missingFrom}, even when another role is queried`, (t) => {
    const directory = temporaryDirectory(t);
    for (const subdirectory of ['scripts', 'roles', 'routing']) mkdirSync(path.join(directory, subdirectory));
    const entrypoint = path.join(directory, 'scripts/query-routing.ps1');
    copyFileSync(script, entrypoint);
    copyFileSync(path.join(packageRoot, 'scripts/project-common.ps1'), path.join(directory, 'scripts/project-common.ps1'));
    const fixtureRouting = structuredClone(routing);
    const fixtureCatalog = structuredClone(catalog);
    const missingRole = 'codebase-scout';
    if (missingFrom === 'routing') delete fixtureRouting.roles[missingRole];
    else fixtureCatalog.roles = fixtureCatalog.roles.filter(({ id }) => id !== missingRole);
    writeFileSync(path.join(directory, 'routing/model-routing.json'), JSON.stringify(fixtureRouting));
    writeFileSync(path.join(directory, 'roles/catalog.json'), JSON.stringify(fixtureCatalog));
    for (const role of [missingRole, 'software-implementer']) {
      const result = query(role, { entrypoint, cwd: directory });
      assert.notEqual(result.status, 0);
      assert.equal(result.stdout, '');
      assert.match(result.stderr, /inconsisten/i);
      for (const text of [missingRole, 'roles/catalog.json', 'routing/model-routing.json']) {
        assert.ok(result.stderr.includes(text), result.stderr);
      }
    }
  });
}

test('capabilities note uses ProjectRoot or cwd and never embeds file contents', (t) => {
  const project = temporaryDirectory(t);
  const otherProject = temporaryDirectory(t);
  const runtime = path.join(project, '.dev-work/runtime');
  mkdirSync(runtime, { recursive: true });
  writeFileSync(path.join(project, capabilitiesPath), 'not JSON: private capabilities contents');
  for (const options of [{ cwd: project }, { cwd: otherProject, projectRoot: project }]) {
    const result = query('codebase-scout', options);
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), {
      ...expectedSlice('codebase-scout'), capabilities: { path: capabilitiesPath },
    });
    assert.ok(Buffer.byteLength(result.stdout) <= 4096);
  }
  const absent = query('codebase-scout', { cwd: project, projectRoot: otherProject });
  assert.equal(absent.status, 0, absent.stderr);
  assert.deepEqual(JSON.parse(absent.stdout), expectedSlice('codebase-scout'));
});
