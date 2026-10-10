import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const packageRoot = fileURLToPath(new URL('../', import.meta.url));
function fixture(context) {
  const root = mkdtempSync(path.join(tmpdir(), 'task-brief-profiles-'));
  context.after(() => rmSync(root, { recursive: true, force: true }));
  writeFileSync(path.join(root, 'AGENTS.md'), '# Rules\n\n## 1. Scope\nKeep scope.\n\n## 5. 任务隔离与分支\nKeep branches.\n\n### Nested\nKeep nested.\n\n## 6. Reports\nReports last.\n');
  const task = JSON.parse(readFileSync(path.join(packageRoot, 'templates/task-definition.json')));
  for (const key of ['taskKind', 'briefProfile', 'agentsSections']) delete task[key];
  task.role = 'software-implementer';
  task.skills = { required: ['test-driven-development'], conditional: [] };
  task.branch.worktree = root;
  return { root, task };
}
function assemble(data, extra = {}, config = null) {
  const taskPath = path.join(data.root, 'task.json');
  const outputPath = path.join(data.root, 'brief.md');
  writeFileSync(taskPath, JSON.stringify({ ...data.task, ...extra }));
  const args = ['-NoProfile', '-NonInteractive', '-File', path.join(packageRoot, 'scripts/assemble-task.ps1'), '-ProjectRoot', data.root, '-TaskDefinitionPath', taskPath, '-OutputPath', outputPath];
  if (config) {
    writeFileSync(path.join(data.root, 'config.json'), JSON.stringify(config));
    args.push('-ConfigPath', 'config.json');
  }
  const result = spawnSync('pwsh', args, { encoding: 'utf8', timeout: 30000 });
  assert.ifError(result.error);
  return { code: result.status, diagnostics: result.stdout + result.stderr, brief: result.status === 0 ? readFileSync(outputPath, 'utf8') : '' };
}

test('AGENTS selection accepts numbers and titles, preserves descendants and source order', (context) => {
  const data = fixture(context);
  const expected = '## 5. 任务隔离与分支\nKeep branches.\n\n### Nested\nKeep nested.\n\n';
  for (const selectors of [['5'], ['任务隔离与分支'], ['Nested', '5', '5. 任务隔离与分支']]) {
    const result = assemble(data, { agentsSections: selectors });
    assert.equal(result.code, 0, result.diagnostics);
    assert.ok(result.brief.endsWith(expected), 'selected AGENTS bytes must be last and unchanged');
    assert.ok(!result.brief.includes('Keep scope.'), 'unselected sections must be omitted');
    assert.equal(result.brief.split('Keep nested.').length, 2, 'overlapping selections must not duplicate content');
  }
});

test('AGENTS selection ignores fenced headings and reports nonexistent selectors', (context) => {
  const data = fixture(context);
  writeFileSync(path.join(data.root, 'AGENTS.md'), '## Keep\n```md\n## Fake\n```\n~~~\n## Also fake\n~~~\n## End\n');
  for (const name of ['Missing', 'Fake', 'Also fake']) {
    const result = assemble(data, { agentsSections: [name] });
    assert.equal(result.code, 1, `selector ${name} must fail`);
    assert.ok(result.diagnostics.includes(name), result.diagnostics);
  }
  const selected = assemble(data, { agentsSections: ['Keep'] });
  assert.equal(selected.code, 0, selected.diagnostics);
  assert.ok(selected.brief.endsWith('## Keep\n```md\n## Fake\n```\n~~~\n## Also fake\n~~~\n'));
});

test('review profile narrows input and supports explicit optional sections', (context) => {
  const data = fixture(context);
  const reviewInput = { baseSha: 'a'.repeat(40), branch: 'implementation/topic', diffCommand: 'git diff ' + 'a'.repeat(40) + '...implementation/topic -- scripts/' };
  data.task.skills.required = ['image-generation'];
  const extra = { taskKind: 'read-only', briefProfile: 'review', reviewInput };
  const result = assemble(data, extra);
  assert.equal(result.code, 0, result.diagnostics);
  const headings = [...result.brief.split('# Applicable Project Rules')[0].matchAll(/^## (.+)$/gm)].map((match) => match[1]);
  assert.deepEqual(headings, ['Task Objective', 'Review input', 'Allowed Scope', 'Forbidden Scope', 'Branch and Worktree Contract', 'Process Artifact Contract', 'Acceptance Criteria', 'Verification', 'Orca Worker Contract', 'Orca Assignment Identity']);
  for (const value of Object.values(reviewInput)) assert.ok(result.brief.includes(value), value);
  assert.ok(!result.brief.includes('Declared Requirements'));
  assert.ok(result.brief.includes('(assigned at dispatch)'));
  const optedIn = assemble(data, { ...extra, reviewIncludes: ['role', 'skills', 'requirements'] });
  assert.equal(optedIn.code, 0, optedIn.diagnostics);
  for (const heading of ['## Primary Role', '## Required and Conditional Skills', '### Declared Requirements']) assert.ok(optedIn.brief.includes(heading), heading);
});

test('new fields deduplicate bound role skill lists while legacy bindings remain unchanged', (context) => {
  const data = fixture(context);
  const config = { schemaVersion: 2, env: {}, roleBindings: { 'software-implementer': { defaultSkills: ['test-driven-development'], optionalSkills: [] } } };
  const legacy = assemble(data, {}, config);
  assert.equal(legacy.code, 0, legacy.diagnostics);
  assert.ok(legacy.brief.includes('defaultSkills:'));
  const defaults = assemble(data, { taskKind: 'source', briefProfile: 'standard', agentsSections: [] }, config);
  assert.equal(defaults.code, 0, defaults.diagnostics);
  assert.equal(defaults.brief, legacy.brief, 'explicit defaults must retain legacy bytes, including role bindings');
  const result = assemble(data, { agentsSections: ['1'] }, config);
  assert.equal(result.code, 0, result.diagnostics);
  const roleBody = result.brief.split('## Primary Role')[1].split('## Required and Conditional Skills')[0];
  assert.ok(!roleBody.includes('defaultSkills:') && !roleBody.includes('optionalSkills:'));
  assert.equal(roleBody.split('test-driven-development').length, 2);
  assert.ok(roleBody.includes('#### 可选专业 Skill\n- None'));
});

test('schema rejects malformed new fields and review briefs without concrete diff input', (context) => {
  const data = fixture(context);
  for (const extra of [{ taskKind: 'readonly' }, { briefProfile: 'compact' }, { agentsSections: '5' }, { agentsSections: [null] }, { agentsSections: [''] }, { briefProfile: 'review' }, { briefProfile: 'review', reviewInput: { baseSha: 'main', branch: 'topic', diffCommand: 'git diff' } }, { reviewIncludes: ['unknown'] }]) {
    const result = assemble(data, extra);
    assert.equal(result.code, 1, `must reject ${JSON.stringify(extra)}`);
    assert.match(result.diagnostics, /schema|reviewInput/);
  }
});

test('implementation section selection cuts at least thirty percent with UTF-8 no BOM and LF output', (context) => {
  const data = fixture(context);
  writeFileSync(path.join(data.root, 'AGENTS.md'), readFileSync(path.join(packageRoot, 'templates/AGENTS.md')));
  data.task.acceptance = ['First criterion', 'Second criterion'];
  data.task.skills.required.push('integration-verification');
  const baseline = assemble(data);
  const selected = assemble(data, { agentsSections: ['1', '5', '10', '12', '14'] });
  assert.equal(baseline.code, 0, baseline.diagnostics);
  assert.equal(selected.code, 0, selected.diagnostics);
  const before = Buffer.byteLength(baseline.brief), after = Buffer.byteLength(selected.brief);
  context.diagnostic(`full=${before} selected=${after} reduction=${((1 - after / before) * 100).toFixed(2)}%`);
  assert.ok(after <= before * 0.7);
  assert.ok(!selected.brief.includes('\r'));
  assert.notEqual(selected.brief.charCodeAt(0), 0xfeff);
});

test('read-only briefs remove the entire source commit clause and retain reporting obligations', (context) => {
  const data = fixture(context);
  const source = assemble(data);
  assert.equal(source.code, 0, source.diagnostics);
  assert.match(source.brief, /Source\/deliverable Tasks: commit/);
  const result = assemble(data, { taskKind: 'read-only' });
  assert.equal(result.code, 0, result.diagnostics);
  assert.doesNotMatch(result.brief, /Source\/deliverable Tasks:|coordinator reviews and merges the committed deliverable/);
  assert.match(result.brief, /Read-only Tasks: produce no commits/);
  assert.match(result.brief, /## Branch and Worktree Contract/);
  assert.match(result.brief, /Send authoritative completion exactly once/);
});
