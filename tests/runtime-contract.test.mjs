import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const changedScripts = ['assemble-task', 'bootstrap-project', 'create-run', 'reconcile-state', 'release-coordinator', 'probe-claude-capabilities', 'project-common'];
const entryScripts = [...changedScripts, 'dispatch-task', 'validate-run', 'verify-package', 'check-requirements', 'invoke-with-requirements', 'query-routing', 'verify-requirements'];
const legacy = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', '$PSVersionTable.PSVersion.Major'], { encoding: 'utf8', timeout: 15000 });

for (const name of entryScripts) {
  test(`${name} declares PowerShell 7 on its first line`, () => {
    assert.match(readFileSync(path.join(root, `scripts/${name}.ps1`), 'utf8').split(/\r?\n/)[0], /^#requires -Version 7\.0$/);
  });
  test(`${name} refuses Windows PowerShell 5.1 before execution`, { skip: legacy.error?.code === 'ENOENT' ? 'powershell.exe is absent on this host' : false }, (t) => {
    assert.ifError(legacy.error);
    assert.equal(legacy.status, 0, legacy.stderr);
    assert.equal(legacy.stdout.trim(), '5');
    const scratch = mkdtempSync(path.join(tmpdir(), 'runtime-refusal-'));
    t.after(() => rmSync(scratch, { recursive: true, force: true }));
    const result = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', path.join(root, `scripts/${name}.ps1`)], { cwd: scratch, encoding: 'utf8', timeout: 15000 });
    assert.ifError(result.error);
    assert.notEqual(result.status, 0);
    assert.match(result.stdout + result.stderr, /ScriptRequiresUnmatchedPSVersion/);
  });
}

for (const name of changedScripts) {
  test(`${name} pins content reads to UTF-8`, () => {
    const source = readFileSync(path.join(root, `scripts/${name}.ps1`), 'utf8');
    for (const line of source.split(/\r?\n/).filter((line) => /\bGet-Content\b/.test(line))) {
      assert.match(line, /-Encoding\s+utf8\b/i, line);
    }
  });
}

function fixture(t, emptyDefaults) {
  const project = mkdtempSync(path.join(tmpdir(), 'runtime-assembly-'));
  t.after(() => rmSync(project, { recursive: true, force: true }));
  const packageRoot = path.join(project, 'package');
  mkdirSync(packageRoot);
  for (const dir of ['scripts', 'schemas', 'roles', 'routing', 'skills', 'references']) {
    cpSync(path.join(root, dir), path.join(packageRoot, dir), { recursive: true });
  }
  const catalogPath = path.join(packageRoot, 'roles/catalog.json');
  const catalog = JSON.parse(readFileSync(catalogPath, 'utf8'));
  const role = catalog.roles.find((entry) => entry.id === 'software-implementer');
  if (emptyDefaults) role.defaultSkills = [];
  writeFileSync(catalogPath, JSON.stringify(catalog));
  const rolePath = path.join(packageRoot, role.path);
  const card = readFileSync(rolePath, 'utf8');
  assert.match(card, /^## 默认专业 Skill\r?$/m);
  writeFileSync(rolePath, card.replace(/^## 默认专业 Skill\r?\n[\s\S]*?(?=^## |$(?![\s\S]))/m, ''));
  writeFileSync(path.join(project, 'AGENTS.md'), '# 规则\n\n中文规则必须保留。\n');
  const task = JSON.parse(readFileSync(path.join(root, 'templates/task-definition.json'), 'utf8'));
  task.role = role.id;
  task.skills = { required: [], conditional: [] };
  task.branch.worktree = project;
  task.objective = '中文任务必须保留。';
  const taskPath = path.join(project, 'task.json');
  writeFileSync(taskPath, JSON.stringify(task));
  return { project, packageRoot, taskPath, outputPath: path.join(project, 'brief.md') };
}

for (const bound of [false, true]) {
  test(`missing default-skill section fails for catalog defaults (binding=${bound})`, (t) => {
    const data = fixture(t, false);
    const result = assemble(data, bound);
    assert.notEqual(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /missing required default-skill section/);
    assert.equal(existsSync(data.outputPath), false);
  });
}

test('role with no catalog defaults succeeds and records skipped substitution', (t) => {
  const data = fixture(t, true);
  const result = assemble(data, true);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(JSON.parse(result.stdout).notes.join('\n'), /default-skill substitution skipped.*catalog defaultSkills is empty/);
  const brief = readFileSync(data.outputPath, 'utf8');
  assert.ok(brief.includes('中文任务必须保留。'));
  assert.ok(brief.includes('中文规则必须保留。'));
});

function assemble(data, bound) {
  const args = ['-NoProfile', '-NonInteractive', '-File', path.join(data.packageRoot, 'scripts/assemble-task.ps1'), '-ProjectRoot', data.project, '-TaskDefinitionPath', data.taskPath, '-OutputPath', data.outputPath];
  if (bound) {
    writeFileSync(path.join(data.project, 'config.json'), JSON.stringify({ schemaVersion: 2, env: {}, roleBindings: { 'software-implementer': { defaultSkills: [], optionalSkills: [] } } }));
    args.push('-ConfigPath', 'config.json');
  }
  const result = spawnSync('pwsh', args, { encoding: 'utf8', timeout: 30000 });
  assert.ifError(result.error);
  return result;
}
