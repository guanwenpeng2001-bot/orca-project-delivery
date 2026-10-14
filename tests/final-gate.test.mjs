import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const script = path.join(root, 'scripts/validate-git-evidence.ps1');

function createProject(t, runSlugArg = runSlug) {
  const project = mkdtempSync(path.join(tmpdir(), 'final-gate-'));
  t.after(() => rmSync(project, { recursive: true, force: true }));
  const git = (args) => {
    const result = spawnSync('git', args, { cwd: project, encoding: 'utf8', timeout: 15000 });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stdout + result.stderr);
  };
  const devWork = path.join(project, '.dev-work');
  // .dev-work is run state, not delivery source: exclude it so the verification worktree
  // reads clean while evidence fixtures live inside the fixture repository.
  mkdirSync(path.join(project, '.git', 'info'), { recursive: true });
  writeFileSync(path.join(project, '.git', 'info', 'exclude'), '.dev-work/\n');
  git(['init', '--template=', '-b', 'main', '-q']);
  git(['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.com', '-c', 'commit.gpgsign=false', 'commit', '--allow-empty', '-q', '-m', 'init']);
  const runDir = path.join(devWork, 'runs', runSlugArg);
  mkdirSync(path.join(runDir, 'evidence', 'git'), { recursive: true });
  mkdirSync(path.join(runDir, 'assignments'), { recursive: true });
  writeFileSync(path.join(devWork, 'active-run.json'), JSON.stringify({ run: runSlugArg }));
  return { project, runDir };
}

function runValidator(project, args) {
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', script,
    '-ProjectRoot', project, ...args], { encoding: 'utf8', timeout: 60000 });
  assert.ifError(result.error);
  return result;
}

function parseStatus(result) {
  return JSON.parse(result.stdout.trim());
}

const at = '2026-10-14T00:00:00Z';
const reviewAt = '2026-10-13T00:00:00Z';
const runSlug = 'gate-run';

for (const phase of ['FINAL', 'Final', 'AUDIT']) {
  for (const emptyCoverage of [false, true]) {
    test(`case variant ${phase} preserves ${emptyCoverage ? 'empty coverage' : 'zero evidence'} verdict`, (t) => {
      const { project } = createProject(t);
      if (emptyCoverage) writeRunFinal(project, []);
      const lower = phase.toLowerCase();
      const expected = lower === 'audit' && !emptyCoverage ? 'NOT_APPLICABLE' : 'FAIL';
      const canonical = runValidator(project, ['-Run', runSlug, '-Phase', lower]);
      const variant = runValidator(project, ['-Run', runSlug, '-Phase', phase]);
      assert.equal(parseStatus(variant).status, expected, variant.stdout);
      assert.equal(variant.status, expected === 'FAIL' ? 1 : 0, variant.stdout);
      assert.deepEqual(parseStatus(variant), parseStatus(canonical));
    });
  }
}

for (const phase of ['SourceRegistered', 'Review', 'PreMerge', 'PostMerge']) {
  test(`case variant ${phase} preserves task phase checks`, (t) => {
    const { project, runDir } = createProject(t);
    integrateFixtureTask(project);
    const evidencePath = path.join(runDir, 'evidence/git/fixture-task.json');
    const document = JSON.parse(readFileSync(evidencePath, 'utf8'));
    document.state = 'reviewed';
    delete document.integration;
    writeFileSync(evidencePath, JSON.stringify(document));
    const lower = phase.toLowerCase();
    const canonical = runValidator(project, ['-EvidencePath', evidencePath, '-Phase', lower]);
    const variant = runValidator(project, ['-EvidencePath', evidencePath, '-Phase', phase]);
    const expected = ['premerge', 'postmerge'].includes(lower) ? 'FAIL' : 'PASS';
    assert.equal(parseStatus(variant).status, expected, variant.stdout);
    assert.equal(variant.status, expected === 'FAIL' ? 1 : 0, variant.stdout);
    assert.equal(parseStatus(variant).phase, lower);
    assert.deepEqual(parseStatus(variant), parseStatus(canonical));
  });
}

// One real task branch merged into the delivery branch, with the review/admission/integration
// chain Test-TaskEvidence demands, so run-final coverage has a legitimate integrated task.
function integrateFixtureTask(project, taskKey = 'fixture-task') {
  const branch = `fixture/${taskKey}`;
  const git = (args, cwd = project) => {
    const result = spawnSync('git', args, { cwd, encoding: 'utf8', timeout: 15000 });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    return result.stdout.trim();
  };
  const identity = ['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.com', '-c', 'commit.gpgsign=false'];
  git(['checkout', '-q', '-b', branch]);
  writeFileSync(path.join(project, 'feature.txt'), `${taskKey}\n`);
  git(['add', 'feature.txt']);
  git([...identity, 'commit', '-q', '-m', 'task work']);
  const taskCommit = git(['rev-parse', 'HEAD']);
  git(['checkout', '-q', 'main']);
  git([...identity, 'merge', '--no-edit', '--no-ff', '-q', branch]);
  const headAfter = git(['rev-parse', 'HEAD']);
  const baselineBefore = git(['rev-parse', 'HEAD~1']);

  const runDir = path.join(project, '.dev-work', 'runs', runSlug);
  const reviewsDir = path.join(runDir, 'reviews');
  mkdirSync(reviewsDir, { recursive: true });
  const reportPath = path.join(reviewsDir, `${taskKey}.md`);
  writeFileSync(reportPath, `# Review: ${taskKey}\n`);

  const review = {
    reviewTaskKey: `${taskKey}-review`,
    reviewer: { taskId: 'task_reviewer00001', dispatchId: 'ctx_reviewer00001' },
    verdict: 'APPROVED',
    reportPath: reportPath,
    target: { branch, commitSha: taskCommit, dirty: false },
    baseline: { branch: 'main', commitSha: baselineBefore },
    recordedAt: reviewAt,
  };
  const taskDocument = {
    schemaVersion: 1,
    run: runSlug,
    subject: { kind: 'task', taskKey },
    state: 'integrated',
    source: {
      branch, worktree: project, reportedCommit: taskCommit,
      workerDone: { messageId: 'msg_000000000001', taskId: 'task_000000000001', dispatchId: 'ctx_000000000001' },
    },
    reviews: [review],
    integration: {
      sourceBranch: branch,
      review: { reviewTaskKey: review.reviewTaskKey, targetCommitSha: taskCommit },
      admission: { sourceHeadSha: taskCommit, sourceWorktreeClean: true, deliveryWorktreeClean: true, checkedAt: reviewAt },
      baselineBefore: { branch: 'main', commitSha: baselineBefore },
      headAfter: { branch: 'main', commitSha: headAfter },
      reviewedSourcePresent: true,
      outcome: 'advanced-clean-merge',
      mergeEvidence: { command: `git merge --no-edit --no-ff ${branch}`, exitCode: 0, conflictFree: true },
      resolution: null,
      checks: [
        { kind: 'observation', command: `git rev-parse ${branch}`, exitCode: 0, observed: taskCommit, commitSha: taskCommit, at: reviewAt },
        { kind: 'observation', command: 'git rev-parse main', exitCode: 0, observed: baselineBefore, commitSha: baselineBefore, at: reviewAt },
        { kind: 'observation', command: 'git rev-parse main', exitCode: 0, observed: headAfter, commitSha: headAfter, at: reviewAt },
        { kind: 'observation', command: 'git status --short', exitCode: 0, observed: '', commitSha: taskCommit, at: reviewAt },
        { kind: 'observation', command: 'git status --short', exitCode: 0, observed: '', commitSha: baselineBefore, at: reviewAt },
        { kind: 'observation', command: 'git status --short', exitCode: 0, observed: '', commitSha: headAfter, at: reviewAt },
        { kind: 'verification', command: 'node --test tests/fixture.test.mjs', exitCode: 0, observed: 'pass 1', commitSha: headAfter, at: reviewAt },
      ],
      recordedAt: reviewAt,
    },
  };
  writeFileSync(path.join(runDir, 'evidence', 'git', `${taskKey}.json`), JSON.stringify(taskDocument, null, 2));
  writeFileSync(path.join(runDir, 'assignments', `${taskKey}.json`), JSON.stringify({
    schemaVersion: 1, taskKey, status: 'completed', branch: { base: 'main', work: branch, mergeTarget: 'main' },
  }));
  return { taskCommit, headAfter, baselineBefore };
}

function writeRunFinal(project, taskKeys, { headAfter } = {}) {
  const head = spawnSync('git', ['-C', project, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).stdout.trim();
  const target = headAfter ?? head;
  const document = {
    schemaVersion: 1,
    run: runSlug,
    subject: { kind: 'run' },
    target: { branch: 'main', commitSha: target },
    worktree: project,
    status: 'verified',
    verdict: 'READY',
    recordedAt: at,
    coverage: { integratedTaskKeys: taskKeys, uncoveredTaskKeys: [] },
    inputs: { integratedEvidencePaths: taskKeys.map((key) => `evidence/git/${key}.json`) },
    checks: [
      { kind: 'observation', command: 'git rev-parse main', exitCode: 0, observed: target, commitSha: target, at },
      { kind: 'observation', command: 'git status --short', exitCode: 0, observed: '', commitSha: target, at },
      { kind: 'verification', command: 'node --test tests/fixture.test.mjs', exitCode: 0, observed: 'pass 1', commitSha: target, at },
    ],
  };
  writeFileSync(path.join(project, '.dev-work', 'runs', runSlug, 'evidence', 'git', 'run-final-verification.json'),
    JSON.stringify(document, null, 2));
}
test('-Phase final with no evidence at all fails closed with exit 1', (t) => {
  const { project } = createProject(t);
  const result = runValidator(project, ['-Run', 'gate-run', '-Phase', 'final']);
  const output = parseStatus(result);
  assert.equal(output.status, 'FAIL', result.stdout + result.stderr);
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.ok(output.errors.some((error) => /No run-final evidence exists/.test(error)), result.stdout);
});

test('-Phase audit with no evidence at all stays NOT_APPLICABLE with exit 0', (t) => {
  const { project } = createProject(t);
  const result = runValidator(project, ['-Run', 'gate-run', '-Phase', 'audit']);
  const output = parseStatus(result);
  assert.equal(output.status, 'NOT_APPLICABLE', result.stdout + result.stderr);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('-Phase final with a valid unique run-final passes with exit 0', (t) => {
  const { project } = createProject(t);
  const { headAfter } = integrateFixtureTask(project);
  writeRunFinal(project, ['fixture-task'], { headAfter });
  const result = runValidator(project, ['-Run', runSlug, '-Phase', 'final']);
  const output = parseStatus(result);
  assert.equal(output.status, 'PASS', `${result.stdout} ${result.stderr}`);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('-Phase final still fails when the run-final is present but coverage is empty', (t) => {
  const { project } = createProject(t);
  integrateFixtureTask(project);
  writeRunFinal(project, []);
  const result = runValidator(project, ['-Run', runSlug, '-Phase', 'final']);
  const output = parseStatus(result);
  assert.equal(output.status, 'FAIL', result.stdout + result.stderr);
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.ok(output.errors.some((error) => /Final coverage integratedTaskKeys must not be empty/.test(error)), result.stdout);
});
