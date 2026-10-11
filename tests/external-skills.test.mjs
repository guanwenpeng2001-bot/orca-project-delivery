import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { cpSync, existsSync, mkdtempSync, mkdirSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const packageRoot = fileURLToPath(new URL('../', import.meta.url));
const quote = (value) => `'${value.replaceAll("'", "''")}'`;
const hash = (file) => createHash('sha256').update(readFileSync(file)).digest('hex');
function run(script, parameters, cwd, sourceRoot = packageRoot) {
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', `$ErrorActionPreference = 'Stop'; & ${quote(path.join(sourceRoot, 'scripts', script))} ${parameters}; exit $LASTEXITCODE`], {
    cwd, encoding: 'utf8', timeout: 30000,
  });
  assert.ifError(result.error);
  return { code: result.status, text: result.stdout + result.stderr, stdout: result.stdout };
}
function fixture(testContext) {
  const root = mkdtempSync(path.join(tmpdir(), 'external-skills-'));
  testContext.after(() => rmSync(root, { recursive: true, force: true }));
  const project = path.join(root, 'project worktree');
  const installed = path.join(root, 'installed skill');
  mkdirSync(project); mkdirSync(path.join(installed, 'resources'), { recursive: true });
  const entry = path.join(installed, 'SKILL.md');
  writeFileSync(entry, '---\nname: upstream-name\n---\n# Installed method\nRead resources/probe.ps1 relative to this Skill directory.\n');
  writeFileSync(path.join(project, 'AGENTS.md'), '# Rules\nPROJECT-RULES-LAST\n');
  const config = { schemaVersion: 2, env: { EXTERNAL_FIXTURE_SETTING: 'synthetic-config' }, externalSkills: [{
    id: 'vendor-method', name: 'Installed method', path: entry, version: 'declared-only',
    requires: { cli: ['pwsh'], env: [{ name: 'EXTERNAL_FIXTURE_SETTING', secret: false, purpose: 'Offline fixture' }] },
  }], roleBindings: { 'software-implementer': { defaultSkills: ['test-driven-development', 'vendor-method'], optionalSkills: ['integration-verification'] } } };
  const configPath = path.join(project, 'project-config.json');
  const save = () => writeFileSync(configPath, JSON.stringify(config));
  save();
  return { root, project, installed, entry, config, configPath, save,
    selection: `-ProjectRoot ${quote(project)} -Role software-implementer -Skills vendor-method -ConfigPath project-config.json` };
}

function assemble(fixtureData, skills, mode = 'explicit-path', configured = true, mutateTask = () => {}) {
  const task = JSON.parse(readFileSync(path.join(packageRoot, 'templates/task-definition.json')));
  task.role = 'software-implementer'; task.branch.worktree = fixtureData.project; task.skillDeliveryMode = mode;
  if (skills === undefined) delete task.skills; else task.skills = skills;
  mutateTask(task);
  const taskPath = path.join(fixtureData.project, 'task.json');
  const output = path.join(fixtureData.project, 'brief.md');
  writeFileSync(taskPath, JSON.stringify(task));
  const result = run('assemble-task.ps1', `-ProjectRoot ${quote(fixtureData.project)} -TaskDefinitionPath ${quote(taskPath)} -OutputPath ${quote(output)} ${configured ? '-ConfigPath project-config.json' : ''}`, fixtureData.project);
  return { ...result, output, brief: result.code === 0 ? readFileSync(output, 'utf8') : '' };
}

test('mixed configured bindings supply omitted selection and explicit arrays override them', (testContext) => {
  const fixtureData = fixture(testContext);
  const result = assemble(fixtureData);
  assert.equal(result.code, 0, result.text);
  assert.deepEqual(JSON.parse(result.stdout).skills, { required: ['test-driven-development', 'vendor-method'], conditional: ['integration-verification'] });
  assert.match(result.brief, /defaultSkills:\r?\n  - test-driven-development\r?\n  - vendor-method/);
  assert.match(result.brief, /optionalSkills:\r?\n  - integration-verification/);
  assert.ok(result.brief.trimEnd().endsWith('PROJECT-RULES-LAST'));
  assert.match(result.brief, /#### 默认专业 Skill\r?\n- test-driven-development, vendor-method/);
  assert.match(result.brief, /#### 可选专业 Skill\r?\n- integration-verification/);
});

for (const configured of [false, true]) {
  const malformed = [
    ['null', null], ['empty object', {}], ['string', 'code-review'], ['array', []], ['number', 1], ['boolean', false],
    ['missing required', { conditional: [] }], ['missing conditional', { required: [] }],
    ['required string', { required: 'code-review', conditional: [] }],
    ['conditional string', { required: [], conditional: 'code-review' }],
    ['required null', { required: null, conditional: [] }],
    ['conditional null', { required: [], conditional: null }],
    ['invalid item', { required: [null], conditional: [] }],
    ['extra field', { required: [], conditional: [], require: [] }],
    ['mistyped skillz', undefined, (task) => { task.skillz = { required: ['code-review'], conditional: [] }; }],
  ];
  for (const [label, skills, mutateTask] of malformed) {
    test(`invalid task skills (${label}, configured=${configured}) fail before writing output`, (testContext) => {
      const fixtureData = fixture(testContext);
      const result = assemble(fixtureData, skills, 'explicit-path', configured, mutateTask);
      assert.equal(result.code, 1, result.text);
      assert.match(result.text, /Task.*skills|skillz.*not supported/);
      assert.ok(!existsSync(result.output));
    });
  }
}

for (const configKind of ['none', 'v1', 'unbound', 'other-role']) {
  test(`omitted task skills with ${configKind} config require a binding for the selected role`, (testContext) => {
    const fixtureData = fixture(testContext);
    if (configKind === 'v1') fixtureData.config = { schemaVersion: 1, env: {} };
    if (configKind === 'unbound') fixtureData.config.roleBindings = {};
    if (configKind === 'other-role') fixtureData.config.roleBindings = { 'code-reviewer': fixtureData.config.roleBindings['software-implementer'] };
    writeFileSync(fixtureData.configPath, JSON.stringify(fixtureData.config));
    const result = assemble(fixtureData, undefined, 'explicit-path', configKind !== 'none');
    assert.equal(result.code, 1, result.text);
    assert.match(result.text, /Task skills.*required.*software-implementer.*configured.*binding/s);
    assert.ok(!existsSync(result.output));
  });
}

for (const mode of ['explicit-path', 'inline-extract']) {
  for (const skills of [{ required: ['code-review'], conditional: ['systematic-debugging'] }, { required: [], conditional: [] }]) {
    test(`explicit task overrides update embedded role selection (${mode}, empty=${skills.required.length === 0})`, (testContext) => {
      const fixtureData = fixture(testContext);
      const rolePath = path.join(packageRoot, 'roles/engineering/software-implementer.md');
      const roleHash = hash(rolePath);
      const result = assemble(fixtureData, skills, mode);
      assert.equal(result.code, 0, result.text);
      assert.deepEqual(JSON.parse(result.stdout).skills, skills);
      assert.deepEqual(JSON.parse(result.stdout).roleBinding, fixtureData.config.roleBindings['software-implementer']);
      const roleBody = result.brief.split('## Primary Role')[1].split('## Required and Conditional Skills')[0];
      for (const [field, heading, selected] of [['defaultSkills', '默认专业 Skill', skills.required], ['optionalSkills', '可选专业 Skill', skills.conditional]]) {
        assert.ok(roleBody.includes(selected.length ? `${field}:\n  - ${selected[0]}\n` : `${field}: []\n`), roleBody);
        assert.ok(roleBody.includes(`#### ${heading}\n- ${selected.join(', ') || 'None'}\n`), roleBody);
      }
      assert.ok(!roleBody.includes('vendor-method') && !roleBody.includes('integration-verification'), roleBody);
      assert.ok(!result.brief.includes('### Skill Provenance'));
      assert.equal(hash(rolePath), roleHash);
    });
  }
}

test('empty configured bindings explicitly render no skills in the embedded role', (testContext) => {
  const fixtureData = fixture(testContext);
  fixtureData.config.roleBindings['software-implementer'] = { defaultSkills: [], optionalSkills: [] };
  fixtureData.save();
  const result = assemble(fixtureData);
  assert.equal(result.code, 0, result.text);
  assert.deepEqual(JSON.parse(result.stdout).skills, { required: [], conditional: [] });
  assert.match(result.brief, /defaultSkills: \[\]/);
  assert.match(result.brief, /optionalSkills: \[\]/);
  assert.match(result.brief, /#### 默认专业 Skill\r?\n- None/);
  assert.match(result.brief, /#### 可选专业 Skill\r?\n- None/);
  assert.doesNotMatch(result.brief, /^-\s*$/m);
});

test('valid legacy task extensions and explicit empty skills remain accepted', (testContext) => {
  const fixtureData = fixture(testContext);
  const result = assemble(fixtureData, { required: [], conditional: [] }, 'explicit-path', false, (task) => { task.projectExtension = 'retained'; });
  assert.equal(result.code, 0, result.text);
  assert.deepEqual(JSON.parse(result.stdout).skills, { required: [], conditional: [] });
  assert.match(result.brief, /Skill delivery mode: `explicit-path`\r?\n\r?\n- None/);
});

test('both delivery modes preserve origin resources and invoke from a separate project', (testContext) => {
  const fixtureData = fixture(testContext);
  const resource = path.join(fixtureData.installed, 'resources', 'probe.ps1');
  writeFileSync(path.join(fixtureData.installed, 'resources', 'sibling.txt'), 'sibling-resource');
  writeFileSync(resource, `if ($env:EXTERNAL_FIXTURE_SETTING -cne 'synthetic-config') { exit 81 }\nif ((Get-Content -LiteralPath (Join-Path $PSScriptRoot 'sibling.txt') -Raw) -cne 'sibling-resource') { exit 82 }\nif ((Get-Location).Path -eq $PSScriptRoot) { exit 83 }\nWrite-Output 'external-resource-ok'\nexit 37\n`);
  const entryHash = hash(fixtureData.entry), resourceHash = hash(resource);
  for (const mode of ['explicit-path', 'inline-extract']) {
    const result = assemble(fixtureData, { required: ['vendor-method'], conditional: [] }, mode);
    assert.equal(result.code, 0, result.text);
    const provenance = JSON.parse(result.stdout).skillProvenance[0];
    assert.equal(provenance.sha256, entryHash);
    assert.ok(result.brief.includes(provenance.path));
    assert.ok(result.brief.includes(provenance.resourceBase));
    assert.match(result.brief, /relative scripts and resources from the original resource base/);
    if (mode === 'inline-extract') {
      assert.match(result.brief, /\n### Installed method\n/);
      assert.match(result.brief, /Later source edits do not update this brief/);
    }
  }
  const result = run('invoke-with-requirements.ps1', `${fixtureData.selection} -Executable pwsh -Arguments @('-NoProfile', '-File', ${quote(resource)})`, fixtureData.project);
  assert.equal(result.code, 37, result.text);
  assert.match(result.text, /external-resource-ok/);
  assert.equal(process.env.EXTERNAL_FIXTURE_SETTING, undefined);
  assert.equal(hash(fixtureData.entry), entryHash);
  assert.equal(hash(resource), resourceHash);
  assert.ok(!existsSync(path.join(fixtureData.project, 'skills', 'vendor-method', 'SKILL.md')));
  const snapshot = readFileSync(path.join(fixtureData.project, 'brief.md'), 'utf8');
  writeFileSync(fixtureData.entry, readFileSync(fixtureData.entry, 'utf8') + '\nEdited after assembly.\n');
  assert.notEqual(hash(fixtureData.entry), entryHash);
  assert.ok(snapshot.includes(entryHash));
  assert.ok(!snapshot.includes('Edited after assembly.'));
});

test('relative registrations resolve independently in each project and helpers select explicitly', (testContext) => {
  const fixtureData = fixture(testContext);
  const hashes = [];
  for (const name of ['first worktree', 'second worktree']) {
    const project = path.join(fixtureData.root, name);
    const entry = path.join(project, 'installed', 'SKILL.md');
    mkdirSync(path.dirname(entry), { recursive: true }); writeFileSync(entry, `# ${name}\n`);
    fixtureData.config.externalSkills[0].path = 'installed/SKILL.md';
    writeFileSync(path.join(project, 'config.json'), JSON.stringify(fixtureData.config));
    const result = run('check-requirements.ps1', `-ProjectRoot ${quote(project)} -Role software-implementer -Skills vendor-method -ConfigPath config.json`, fixtureData.root);
    assert.equal(result.code, 0, result.text);
    hashes.push(JSON.parse(result.stdout).skillProvenance[0].sha256);
    const roleOnly = run('check-requirements.ps1', `-ProjectRoot ${quote(project)} -Role software-implementer -ConfigPath config.json`, fixtureData.root);
    assert.equal(roleOnly.code, 0, roleOnly.text);
    assert.deepEqual(JSON.parse(roleOnly.stdout).checks, []);
  }
  assert.notEqual(hashes[0], hashes[1]);
});

test('invalid registrations fail closed with names and no configuration values', (testContext) => {
  const fixtureData = fixture(testContext);
  const original = structuredClone(fixtureData.config);
  const cases = [
    ['collision', (config) => { config.externalSkills[0].id = 'test-driven-development'; }, /collides/],
    ['duplicate', (config) => { config.externalSkills.push(config.externalSkills[0]); }, /collides/],
    ['missing', (config) => { config.externalSkills[0].path = 'missing/SKILL.md'; }, /vendor-method.*project-config.json.*declared path/],
    ['directory', (config) => { config.externalSkills[0].path = fixtureData.installed; }, /must be a file/],
    ['traversal', (config) => { config.externalSkills[0].path = '../installed skill/SKILL.md'; }, /traversal/],
    ['host feature', (config) => { config.externalSkills[0].hooks = 'synthetic-private'; }, /schema/],
    ['v1 extension', (config) => { config.schemaVersion = 1; }, /schema/],
    ['unknown role', (config) => { config.roleBindings = { missing: { defaultSkills: [], optionalSkills: [] } }; }, /unknown role/],
    ['unknown skill', (config) => { config.roleBindings['software-implementer'].optionalSkills = ['missing']; }, /unknown skill 'missing'/],
    ['unsupported requirement', (config) => { config.externalSkills[0].requires.hooks = 'synthetic-private'; }, /vendor-method.*schema/],
    ['undeclared auth', (config) => { config.externalSkills[0].requires.api = [{ name: 'offline-api', authEnv: 'UNDECLARED', purpose: 'Offline' }]; }, /undeclared env UNDECLARED/],
    ['duplicate env', (config) => { config.externalSkills[0].requires.env.push(config.externalSkills[0].requires.env[0]); }, /Duplicate env requirement/],
    ['secret config', (config) => { config.externalSkills[0].requires.env[0].secret = true; }, /declared non-secret/],
  ];
  for (const [label, mutate, diagnostic] of cases) {
    const config = structuredClone(original); mutate(config);
    writeFileSync(fixtureData.configPath, JSON.stringify(config));
    const result = run('check-requirements.ps1', fixtureData.selection, fixtureData.project);
    assert.equal(result.code, 1, `${label}: ${result.text}`);
    assert.match(result.text, diagnostic, label);
    assert.ok(!result.text.includes('synthetic-config') && !result.text.includes('synthetic-private'), label);
  }
});

test('links are explicitly unsupported and config remains project-confined', (testContext) => {
  const fixtureData = fixture(testContext);
  const link = path.join(fixtureData.project, 'linked');
  symlinkSync(fixtureData.installed, link, process.platform === 'win32' ? 'junction' : 'dir');
  fixtureData.config.externalSkills[0].path = 'linked/SKILL.md'; fixtureData.save();
  const linked = run('check-requirements.ps1', fixtureData.selection, fixtureData.project);
  assert.equal(linked.code, 1, linked.text); assert.match(linked.text, /Linked catalog paths are not supported/);
  const outside = path.join(fixtureData.root, 'outside.json'); writeFileSync(outside, JSON.stringify({ schemaVersion: 1, env: {} }));
  const rejected = run('check-requirements.ps1', `-ProjectRoot ${quote(fixtureData.project)} -Role software-implementer -ConfigPath ${quote(outside)}`, fixtureData.project);
  assert.equal(rejected.code, 1); assert.match(rejected.text, /inside the explicit project root/);
});

test('missing declared dependencies block the child and unknown selection writes no brief', (testContext) => {
  const fixtureData = fixture(testContext);
  fixtureData.config.env = {};
  fixtureData.config.externalSkills[0].requires.cli = ['external-fixture-missing-command'];
  fixtureData.config.externalSkills[0].requires.api = [{ name: 'offline-api', authEnv: 'EXTERNAL_FIXTURE_SETTING', purpose: 'Name only' }];
  fixtureData.save();
  const checked = run('check-requirements.ps1', fixtureData.selection, fixtureData.project);
  assert.equal(checked.code, 1, checked.text);
  assert.deepEqual(JSON.parse(checked.stdout).missing.sort(), ['api:offline-api', 'cli:external-fixture-missing-command', 'env:EXTERNAL_FIXTURE_SETTING']);
  const child = run('invoke-with-requirements.ps1', `${fixtureData.selection} -Executable pwsh -Arguments @('-Command', 'Write-Output forbidden-child')`, fixtureData.project);
  assert.equal(child.code, 1); assert.ok(!child.text.includes('forbidden-child'));
  const missingConfig = assemble(fixtureData, { required: ['vendor-method'], conditional: [] }, 'explicit-path', false);
  assert.equal(missingConfig.code, 1); assert.match(missingConfig.text, /Unknown skill selector.*no -ConfigPath supplied/);
  assert.ok(!existsSync(missingConfig.output));
});

test('selected external and bundled requirement conflicts are rejected', (testContext) => {
  const fixtureData = fixture(testContext);
  fixtureData.config.env = {};
  fixtureData.config.externalSkills[0].requires.env = [{ name: 'OPENAI_IMAGE_MODEL', secret: false, purpose: 'Conflicting metadata' }]; fixtureData.save();
  const result = run('check-requirements.ps1', `-ProjectRoot ${quote(fixtureData.project)} -Role software-implementer -Skills @('vendor-method', 'image-generation') -ConfigPath project-config.json`, fixtureData.project);
  assert.equal(result.code, 1); assert.match(result.text, /Conflicting metadata for env OPENAI_IMAGE_MODEL/);
});

test('external alias does not consult a same-named package directory', (testContext) => {
  const fixtureData = fixture(testContext);
  const isolatedPackage = path.join(fixtureData.root, 'package'); mkdirSync(isolatedPackage);
  for (const directory of ['scripts', 'schemas', 'roles', 'routing', 'skills']) cpSync(path.join(packageRoot, directory), path.join(isolatedPackage, directory), { recursive: true });
  mkdirSync(path.join(isolatedPackage, 'skills', 'vendor-method'));
  writeFileSync(path.join(isolatedPackage, 'skills', 'vendor-method', 'SKILL.md'), '# DECOY\n');
  const result = run('check-requirements.ps1', fixtureData.selection, fixtureData.project, isolatedPackage);
  assert.equal(result.code, 0, result.text);
  assert.equal(JSON.parse(result.stdout).skillProvenance[0].sha256, hash(fixtureData.entry));
});

test('config v1 remains env-only and explicit process values keep precedence', (testContext) => {
  const fixtureData = fixture(testContext);
  writeFileSync(fixtureData.configPath, JSON.stringify({ schemaVersion: 1, env: {} }));
  const legacy = run('check-requirements.ps1', `-ProjectRoot ${quote(fixtureData.project)} -Role software-implementer -ConfigPath project-config.json`, fixtureData.project);
  assert.equal(legacy.code, 0, legacy.text); assert.deepEqual(JSON.parse(legacy.stdout).checks, []);
  fixtureData.save();
  const command = `$ErrorActionPreference = 'Stop'; . ${quote(path.join(packageRoot, 'scripts/requirements-lib.ps1'))}; $parent = @{ EXTERNAL_FIXTURE_SETTING = 'process-choice' }; $resolution = Resolve-RequirementAvailability -ProjectRoot ${quote(fixtureData.project)} -RoleId software-implementer -SkillIds vendor-method -ConfigPath project-config.json -ProcessEnvironment $parent; $child = Get-ChildRequirementEnvironment $resolution; if ($child['EXTERNAL_FIXTURE_SETTING'] -cne 'process-choice' -or $parent.Count -ne 1) { throw 'Precedence or parent mutation' }; $parent['EXTERNAL_FIXTURE_SETTING'] = ''; $empty = Resolve-RequirementAvailability -ProjectRoot ${quote(fixtureData.project)} -RoleId software-implementer -SkillIds vendor-method -ConfigPath project-config.json -ProcessEnvironment $parent; if ($empty.Missing -notcontains 'env:EXTERNAL_FIXTURE_SETTING') { throw 'Empty process value fell through' }`;
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', command], { cwd: fixtureData.project, encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('legacy bundled briefs retain their exact normalized bytes in both modes', (testContext) => {
  const fixtureData = fixture(testContext);
  for (const [mode, expected] of Object.entries({ 'explicit-path': '103d5e33517f56cc04d7542b5f7245f66267617f7d1e572203b51a8b2f266c84', 'inline-extract': 'dc0a717a015b67c038b8f5642f6241078e8e857d3e4d390eb31a33253201831a' })) {
    const result = assemble(fixtureData, { required: ['test-driven-development', 'test-driven-development'], conditional: ['integration-verification'] }, mode, false);
    assert.equal(result.code, 0, result.text);
    let normalized = result.brief.replaceAll('\\', '/');
    for (const root of [realpathSync.native(packageRoot), packageRoot]) normalized = normalized.replaceAll(root.replaceAll('\\', '/').replace(/\/$/, ''), '<PACKAGE>');
    for (const root of [realpathSync.native(fixtureData.project), fixtureData.project]) normalized = normalized.replaceAll(root.replaceAll('\\', '/'), '<PROJECT>');
    assert.equal(createHash('sha256').update(normalized).digest('hex'), expected, mode);
  }
});

test('installed alias participates in preflight without rewriting its origin', (testContext) => {
  const fixtureData = fixture(testContext);
  const before = hash(fixtureData.entry);
  const result = run('check-requirements.ps1', fixtureData.selection, fixtureData.project);
  assert.equal(result.code, 0, result.text);
  const report = JSON.parse(result.stdout);
  assert.equal(report.ok, true);
  assert.equal(report.checks.find((item) => item.name === 'EXTERNAL_FIXTURE_SETTING').source, 'project-config');
  assert.equal(report.skillProvenance[0].id, 'vendor-method');
  assert.equal(report.skillProvenance[0].origin, 'project-external');
  assert.equal(report.skillProvenance[0].sha256.toLowerCase(), before);
  assert.equal(report.skillProvenance[0].declaredVersion, 'declared-only');
  assert.equal(realpathSync.native(report.skillProvenance[0].resourceBase), realpathSync.native(fixtureData.installed));
  assert.equal(hash(fixtureData.entry), before);
  assert.ok(!result.text.includes('synthetic-config'));
});
