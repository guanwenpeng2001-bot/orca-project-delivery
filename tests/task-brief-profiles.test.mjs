import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const packageRoot = fileURLToPath(new URL('../', import.meta.url));

// PowerShell renders thrown messages with ANSI colors and hard line wraps; flatten both before
// matching so an assertion does not depend on the console width of the day.
function clean(text) {
  return text
    .replace(/\x1b\[[0-9;]*m/g, '')
    .replace(/\r?\n\s*\|\s*/g, ' ')
    .replace(/\s+/g, ' ');
}

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
function assemble(data, extra = {}, config = null, sourceRoot = packageRoot) {
  const taskPath = path.join(data.root, 'task.json');
  const outputPath = path.join(data.root, 'brief.md');
  writeFileSync(taskPath, JSON.stringify({ ...data.task, ...extra }));
  const args = ['-NoProfile', '-NonInteractive', '-File', path.join(sourceRoot, 'scripts/assemble-task.ps1'), '-ProjectRoot', data.root, '-TaskDefinitionPath', taskPath, '-OutputPath', outputPath];
  if (config) {
    writeFileSync(path.join(data.root, 'config.json'), JSON.stringify(config));
    args.push('-ConfigPath', 'config.json');
  }
  const result = spawnSync('pwsh', args, { encoding: 'utf8', timeout: 30000 });
  assert.ifError(result.error);
  return { code: result.status, diagnostics: result.stdout + result.stderr, brief: result.status === 0 ? readFileSync(outputPath, 'utf8') : '' };
}

test('game roles assemble their registered methods in both delivery modes', (context) => {
  const data = fixture(context);
  for (const [role, skills] of Object.entries({
    'game-designer': ['game-design', 'game-economy-design', 'game-level-design'],
    'game-test-engineer': ['game-testing-ladders'],
  })) {
    for (const mode of ['explicit-path', 'inline-extract']) {
      const result = assemble(data, { role, skills: { required: skills, conditional: [] }, skillDeliveryMode: mode });
      assert.equal(result.code, 0, result.diagnostics);
      assert.ok(result.brief.includes(role));
      for (const skill of skills) {
        assert.ok(result.brief.includes(skill));
        if (mode === 'inline-extract') {
          const body = readFileSync(path.join(packageRoot, 'skills', skill, 'SKILL.md'), 'utf8').trim();
          assert.ok(result.brief.includes(body), skill);
        }
      }
    }
  }
});

test('legacy bundled briefs assemble with contract and structure in both modes', (context) => {
  const data = fixture(context);
  for (const mode of ['explicit-path', 'inline-extract']) {
    const result = assemble(data, { skills: { required: ['test-driven-development', 'test-driven-development'], conditional: ['integration-verification'] }, skillDeliveryMode: mode });
    assert.equal(result.code, 0, result.diagnostics);
    assert.ok(result.brief.includes('Run bounded commands only'), mode);
    assert.ok(result.brief.includes('## Acceptance Criteria'), mode);
    assert.ok(result.brief.includes('## Orca Worker Contract'), mode);
    if (mode === 'explicit-path') {
      assert.ok(/skills[/\\]test-driven-development[/\\]SKILL\.md/.test(result.brief), mode);
    } else {
      const body = readFileSync(path.join(packageRoot, 'skills', 'test-driven-development', 'SKILL.md'), 'utf8').trim();
      assert.ok(result.brief.includes(body), mode);
    }
  }
});

test('script validation follows the worker copy from stale control and delivery assemblers', (context) => {
  const data = fixture(context);
  const control = path.join(data.root, 'control');
  const worker = path.join(data.root, 'worker');
  mkdirSync(control);
  mkdirSync(path.join(worker, 'scripts'), { recursive: true });
  for (const directory of ['scripts', 'schemas', 'roles', 'routing', 'skills', 'references']) {
    cpSync(path.join(packageRoot, directory), path.join(control, directory), { recursive: true });
  }
  writeFileSync(path.join(control, 'scripts/verify-package.ps1'), 'param([string]$PackageRoot, [switch]$MetadataOnly)\n');
  cpSync(path.join(packageRoot, 'scripts/verify-package.ps1'), path.join(worker, 'scripts/verify-package.ps1'));
  for (const name of ['check-requirements.ps1', 'invoke-with-requirements.ps1']) {
    cpSync(path.join(packageRoot, 'scripts', name), path.join(worker, 'scripts', name));
  }
  data.task.branch.worktree = worker;
  data.task.skills.required = ['image-generation'];
  data.task.acceptance = [];
  data.task.tests = ["pwsh scripts/verify-package.ps1 -Suites 'package structure,project lifecycle'"];
  for (const [label, source] of [['control', control], ['delivery', packageRoot]]) {
    const result = assemble(data, {}, null, source);
    assert.equal(result.code, 0, label + ': ' + result.diagnostics);
    assert.equal(path.resolve(JSON.parse(result.diagnostics).scriptSourceRoot), path.join(worker, 'scripts'));
    for (const name of ['check-requirements.ps1', 'invoke-with-requirements.ps1']) {
      assert.ok(result.brief.includes(path.join(worker, 'scripts', name)), name);
    }
    context.diagnostic(label + ' invocation: -Suites accepted against worker scripts');
  }
  writeFileSync(path.join(worker, 'scripts/verify-package.ps1'), 'param([string]$PackageRoot)\n');
  const refused = assemble(data);
  assert.equal(refused.code, 1, refused.diagnostics);
  assert.match(clean(refused.diagnostics), /no parameter '-Suites'/);
  context.diagnostic('inverse divergence: worker missing -Suites rejected');
  writeFileSync(path.join(worker, 'scripts/worker-only.ps1'), 'param([string]$Allowed)\n');
  const bare = assemble(data, { tests: ['worker-only.ps1 -Unknown'] });
  assert.equal(bare.code, 1, bare.diagnostics);
  assert.match(clean(bare.diagnostics), /no parameter '-Unknown'/);
  const fallback = assemble(data, { tests: ['scripts/query-routing.ps1 -Role software-implementer'] });
  assert.equal(fallback.code, 0, fallback.diagnostics);
});

test('assembled lifecycle contract carries identity and reporting obligations', (context) => {
  const result = assemble(fixture(context));
  assert.equal(result.code, 0, result.diagnostics);
  for (const text of ['--type heartbeat', 'orca orchestration ask', '--task-id', '--dispatch-id', 'git show --stat', 'paraphrase']) {
    assert.ok(result.brief.includes(text), text);
  }
});

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
  data.task.branch.mergeTarget = null;
  const extra = { taskKind: 'read-only', briefProfile: 'review', reviewInput };
  const result = assemble(data, extra);
  assert.equal(result.code, 0, result.diagnostics);
  const headings = [...result.brief.split('# Applicable Project Rules')[0].matchAll(/^## (.+)$/gm)].map((match) => match[1]);
  assert.deepEqual(headings, ['Task Objective', 'Review input', 'Allowed Scope', 'Forbidden Scope', 'Branch and Worktree Contract', 'Process Artifact Contract', 'Acceptance Criteria', 'Verification', 'Orca Worker Contract', 'Orca Assignment Identity']);
  for (const value of Object.values(reviewInput)) assert.ok(result.brief.includes(value), value);
  assert.ok(!result.brief.includes('Declared Requirements'));
  assert.ok(result.brief.includes('(assigned at dispatch)'));
  const withEvidence = assemble(data, { ...extra, reviewInput: { ...reviewInput, coordinatorEvidence: ['credential scan: zero hits', 'ls-files comparison: identical'] } });
  assert.equal(withEvidence.code, 0, withEvidence.diagnostics);
  assert.ok(withEvidence.brief.includes('Coordinator-precomputed evidence (audit, do not re-run):'));
  assert.ok(withEvidence.brief.includes('- credential scan: zero hits'));
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
  for (const extra of [
    { taskKind: 'source', branch: { ...data.task.branch, mergeTarget: null } },
    { branch: { ...data.task.branch, mergeTarget: null } },
    { taskKind: 'source', branch: { ...data.task.branch, mergeTarget: '' } },
    { taskKind: 'read-only', branch: { ...data.task.branch, mergeTarget: 'main' } },
  ]) {
    const result = assemble(data, extra);
    assert.equal(result.code, 1, `must reject ${JSON.stringify(extra)}`);
    assert.match(result.diagnostics, /schema/);
  }
  const validReviewInput = { baseSha: 'a'.repeat(40), branch: 'topic', diffCommand: 'git diff' };
  for (const extra of [{ taskKind: 'readonly' }, { briefProfile: 'compact' }, { agentsSections: '5' }, { agentsSections: [null] }, { agentsSections: [''] }, { briefProfile: 'review' }, { briefProfile: 'review', reviewInput: { baseSha: 'main', branch: 'topic', diffCommand: 'git diff' } }, { reviewIncludes: ['unknown'] }, { briefProfile: 'review', reviewInput: { ...validReviewInput, deltaPaths: 'scripts/x.ps1' } }, { briefProfile: 'review', reviewInput: { ...validReviewInput, deltaPaths: [1] } }, { briefProfile: 'review', reviewInput: { ...validReviewInput, deltaPaths: [''] } }]) {
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
  data.task.branch.mergeTarget = null;
  const result = assemble(data, { taskKind: 'read-only' });
  assert.equal(result.code, 0, result.diagnostics);
  assert.doesNotMatch(result.brief, /Source\/deliverable Tasks:|coordinator reviews and merges the committed deliverable/);
  assert.match(result.brief, /Read-only Tasks: produce no commits/);
  assert.match(result.brief, /## Branch and Worktree Contract/);
  assert.match(result.brief, /Send authoritative completion exactly once/);
});

test('acceptance and tests commands are checked against the real package scripts and parameters', (context) => {
  const data = fixture(context);
  data.task.acceptance = ['Full gate: pwsh -NoProfile -File scripts/verify-package.ps1 -MetadataOnly', 'Routing check: pwsh scripts/query-routing.ps1 -Role software-implementer'];
  data.task.tests = ['node --test tests/task-brief-profiles.test.mjs', 'git merge --no-edit topic', 'pwsh -NoProfile -File scripts/verify-package.ps1'];
  const valid = assemble(data);
  assert.equal(valid.code, 0, valid.diagnostics);
  for (const command of [...data.task.acceptance, ...data.task.tests]) assert.ok(valid.brief.includes(command), command);

  const rejected = [
    ['scripts/nonexistent-runner.ps1 -X', /does not exist/],
    ['pwsh -NoProfile -File scripts/verify-package.ps1 -Run nightly', /no parameter '-Run'/],
    ['query-routing.ps1 -Force', /no parameter '-Force'/],
  ];
  for (const [command, pattern] of rejected) {
    const negative = assemble(data, { tests: [command] });
    assert.equal(negative.code, 1, `must reject ${command}`);
    assert.match(clean(negative.diagnostics), pattern);
  }
  assert.equal(existsSync(path.join(data.root, 'brief.md')), true, 'the earlier valid brief stays; failed runs must not overwrite it');
  const fresh = fixture(context);
  const refused = assemble(fresh, { acceptance: ['pwsh -NoProfile -File scripts/verify-package.ps1 -Run nightly'] });
  assert.equal(refused.code, 1, refused.diagnostics);
  assert.equal(existsSync(path.join(fresh.root, 'brief.md')), false, 'a failed assembly writes no brief');
});

test('verification clauses scale with the brief profile and print review deltas', (context) => {
  const data = fixture(context);
  const standard = assemble(data);
  assert.equal(standard.code, 0, standard.diagnostics);
  assert.match(standard.brief, /### Minimum relevant suites/);
  assert.ok(standard.brief.includes('A change that can move assembled brief bytes must include `tests/task-brief-profiles.test.mjs` in its write set and required tests.'));
  assert.doesNotMatch(standard.brief, /### Re-verification scaled by the delta/);
  assert.match(standard.brief, /scripts\/verify-package\.ps1 -Suites/);
  assert.match(standard.brief, /-Suites 'package contracts,project lifecycle'/);
  for (const suite of ['package structure', 'package runtime', 'package contracts', 'project lifecycle']) {
    assert.ok(standard.brief.includes(suite), `standard brief must name suite: ${suite}`);
  }

  const reviewInput = { baseSha: 'b'.repeat(40), branch: 'implementation/topic', diffCommand: 'git diff ' + 'b'.repeat(40) + '...implementation/topic' };
  const review = assemble(data, { briefProfile: 'review', reviewInput });
  assert.equal(review.code, 0, review.diagnostics);
  assert.match(review.brief, /### Re-verification scaled by the delta/);
  assert.doesNotMatch(review.brief, /### Minimum relevant suites/);
  assert.doesNotMatch(review.brief, /Delta paths recorded/);

  const withDelta = assemble(data, { briefProfile: 'review', reviewInput: { ...reviewInput, deltaPaths: ['scripts/assemble-task.ps1', 'tests/task-brief-profiles.test.mjs'] } });
  assert.equal(withDelta.code, 0, withDelta.diagnostics);
  assert.match(withDelta.brief, /Delta paths recorded against the reviewed revision:/);
  assert.ok(withDelta.brief.includes('- `scripts/assemble-task.ps1`'), withDelta.brief.slice(0, 400));
  const headings = [...withDelta.brief.split('# Applicable Project Rules')[0].matchAll(/^## (.+)$/gm)].map((match) => match[1]);
  assert.deepEqual(headings, ['Task Objective', 'Review input', 'Allowed Scope', 'Forbidden Scope', 'Branch and Worktree Contract', 'Process Artifact Contract', 'Acceptance Criteria', 'Verification', 'Orca Worker Contract', 'Orca Assignment Identity']);
});
