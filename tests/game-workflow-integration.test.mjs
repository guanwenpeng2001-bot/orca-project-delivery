import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';

const root = path.resolve(import.meta.dirname, '..');
const read = (file) => readFileSync(path.join(root, file), 'utf8');

function run(command, args, cwd) {
  const result = spawnSync(command, args, { cwd, encoding: 'utf8', timeout: 60000 });
  assert.ifError(result.error);
  return { status: result.status, text: result.stdout + result.stderr };
}

function temporary(context, prefix) {
  const directory = mkdtempSync(path.join(tmpdir(), prefix));
  context.after(() => rmSync(directory, { recursive: true, force: true }));
  return directory;
}

test('all five workflows create runs and persist the selected workflow', (context) => {
  const directory = temporary(context, 'game-workflow-runs-');
  for (const workflow of ['feature-development', 'bug-fix', 'refactor', 'audit', 'game-development']) {
    const project = path.join(directory, workflow);
    mkdirSync(project);
    const initialized = run('git', ['init', '-b', 'control'], project);
    assert.equal(initialized.status, 0, initialized.text);
    const bootstrap = run('pwsh', ['-NoProfile', '-NonInteractive', '-File', path.join(root, 'scripts/bootstrap-project.ps1'),
      '-ProjectRoot', project, '-DeliveryBranch', 'main'], project);
    assert.equal(bootstrap.status, 0, bootstrap.text);
    const result = run('pwsh', ['-NoProfile', '-NonInteractive', '-File', path.join(root, 'scripts/create-run.ps1'),
      '-ProjectRoot', project, '-Objective', 'Workflow acceptance', '-Workflow', workflow,
      '-DeliveryBranch', 'main', '-RunSlug', 'workflow-acceptance'], project);
    assert.equal(result.status, 0, result.text);
    const state = JSON.parse(readFileSync(path.join(project, '.dev-work/runs/workflow-acceptance/run-state.json')));
    assert.equal(state.workflow, workflow);
    assert.equal(state.stage, 'intake');
    assert.equal(state.deliveryBranch, 'main');
  }
});

test('metadata validation rejects nonexistent workflow rule and default targets', (context) => {
  const directory = temporary(context, 'game-workflow-paths-');
  cpSync(root, directory, { recursive: true, filter: (source) => !['.git', '.dev-work'].includes(path.basename(source)) });
  const original = JSON.parse(read('routing/workflow-selection.json'));
  for (const target of ['rule', 'default', 'missing-key']) {
    const selection = structuredClone(original);
    if (target === 'rule') selection.rules[0].workflow = 'missing-workflow';
    else if (target === 'missing-key') delete selection.rules[0].workflow;
    else selection.default = 'missing-workflow';
    writeFileSync(path.join(directory, 'routing/workflow-selection.json'), JSON.stringify(selection, null, 2) + '\n');
    const result = run('pwsh', ['-NoProfile', '-NonInteractive', '-File',
      path.join(directory, 'scripts/verify-package.ps1'), '-MetadataOnly'], directory);
    assert.equal(result.status, 1, result.text);
    assert.match(result.text, target === 'missing-key'
      ? /workflow: rule missing name/
      : /workflow: missing definition missing-workflow/);
  }
});

test('game skill catalog metadata mirrors all 23 bundled frontmatter records', () => {
  const catalog = JSON.parse(read('routing/skill-catalog.json'));
  const games = catalog.skills.filter(({ id }) => /^(game-|gameplay-|engine-)/.test(id));
  assert.equal(games.length, 23);
  for (const entry of games) {
    const body = read(entry.path.replaceAll('\\', '/'));
    assert.equal(entry.name, body.match(/^name: (.+)$/m)?.[1], entry.id);
    assert.equal(entry.description, body.match(/^description: (.+)$/m)?.[1], entry.id);
  }
});
