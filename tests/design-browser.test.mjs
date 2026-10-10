import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { existsSync, mkdtempSync, mkdirSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const script = path.join(root, 'skills', 'frontend-visual-design', 'scripts', 'contrast-ratio.mjs');

function run(args) {
  const result = spawnSync(process.execPath, [script, ...args], {
    cwd: root,
    encoding: 'utf8',
    env: { PATH: process.env.PATH, SystemRoot: process.env.SystemRoot },
    timeout: 15000,
  });
  assert.notEqual(result.status, null, result.error && result.error.message);
  return result;
}

function reportOf(result) {
  assert.equal(result.stderr, '', result.stderr);
  return JSON.parse(result.stdout);
}

test('black on white is 21:1 and meets both text and boundary thresholds', () => {
  const result = run(['--foreground', '#000000', '--background', '#ffffff']);
  assert.equal(result.status, 0, result.stderr);
  const report = reportOf(result);
  assert.equal(report.ratioRounded, 21);
  assert.equal(report.ratio, 21);
  assert.equal(report.meets.text, true);
  assert.equal(report.meets.boundary, true);
  assert.equal(report.threshold, null);
});

test('the same pair is symmetric and short hex expands to the same ratio', () => {
  const long = reportOf(run(['--foreground', '#ffffff', '--background', '#000']));
  assert.equal(long.ratioRounded, 21);
  assert.equal(long.foreground, '#FFFFFF');
  assert.equal(long.background, '#000000');
});

test('a large-text pair meets 3:1 and fails ordinary 4.5:1 text', () => {
  const result = run(['--foreground', '#777777', '--background', '#FFFFFF']);
  assert.equal(result.status, 0, result.stderr);
  const report = reportOf(result);
  assert.ok(report.ratioRounded > 4 && report.ratioRounded < 4.5, `expected between 4 and 4.5, got ${report.ratioRounded}`);
  assert.equal(report.meets.text, false);
  assert.equal(report.meets.boundary, true);
});

test('an accent that misses the requested text threshold exits nonzero and still reports the ratio', () => {
  const result = run(['--foreground', '#777777', '--background', '#FFFFFF', '--threshold', '4.5']);
  assert.notEqual(result.status, 0);
  const report = JSON.parse(result.stdout);
  assert.equal(report.meets.requested, false);
  assert.equal(report.threshold, 4.5);
  assert.ok(report.ratio < 4.5);
  assert.ok(report.ratioRounded > 4.5 * 0.95, `expected near the 4.5 boundary, got ${report.ratioRounded}`);
});

test('the same near-boundary accent passes when only the 3:1 boundary is requested', () => {
  const result = run(['--foreground', '#777777', '--background', '#FFFFFF', '--threshold', '3']);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).meets.requested, true);
});

test('equal colors are 1:1 and fail every requested threshold', () => {
  const result = run(['--foreground', '#336699', '--background', '#336699', '--threshold', '3']);
  assert.notEqual(result.status, 0);
  const report = JSON.parse(result.stdout);
  assert.equal(report.ratioRounded, 1);
  assert.equal(report.ratio, 1);
  assert.equal(report.meets.text, false);
  assert.equal(report.meets.boundary, false);
  assert.equal(report.meets.requested, false);
});

test('malformed color, alpha, and an unknown threshold exit nonzero with no report', () => {
  for (const args of [
    ['--foreground', '#12', '--background', '#000000'],
    ['--foreground', '#00000080', '--background', '#ffffff'],
    ['--foreground', 'black', '--background', '#ffffff'],
    ['--foreground', '#000000', '--background', '#ffffff', '--threshold', '7'],
    ['--foreground', '#000000'],
  ]) {
    const result = run(args);
    assert.notEqual(result.status, 0, args.join(' '));
    assert.equal(result.stdout, '', args.join(' '));
    assert.match(result.stderr, /contrast-ratio:/);
  }
});

test('a fixture page states the same ratios the calculator reports', () => {
  const fixture = readFileSync(path.join(root, 'tests', 'fixtures', 'capability', 'design-browser-page.html'), 'utf8');
  assert.ok(fixture.length > 0);
  const pairs = [...fixture.matchAll(/data-contrast="(#[0-9a-fA-F]{6}) (#[0-9a-fA-F]{6}) ([0-9.]+)"/g)];
  assert.ok(pairs.length >= 2);
  for (const [, foreground, background, expected] of pairs) {
    const report = reportOf(run(['--foreground', foreground, '--background', background]));
    assert.equal(report.ratioRounded, Number(expected));
  }
});

test('the maintained runner names the success journey, the refusal, and the seeded defect', () => {
  const runner = readFileSync(path.join(root, 'skills', 'browser-e2e', 'scripts', 'run-tide-journeys.mjs'), 'utf8');
  const driver = readFileSync(path.join(root, 'skills', 'browser-e2e', 'scripts', 'run_tide_journeys.py'), 'utf8');
  assert.match(runner, /saves a tide reading/);
  assert.match(runner, /refuses a blank tide time/);
  assert.match(runner, /seedDefect/);
  assert.match(driver, /keyboard|press_sequentially/);
  assert.equal(existsSync(path.join(root, 'skills', 'browser-e2e', 'scripts', 'sample.spec.mjs')), false);
});

test('bridge and driver journey names agree and navigation only separates journeys', { skip: pythonUnavailable() }, async () => {
  const runnerPath = path.join(root, 'skills', 'browser-e2e', 'scripts', 'run-tide-journeys.mjs');
  const { tideJourneys } = await import(pathToFileURL(runnerPath).href);
  const driverPath = path.join(root, 'skills', 'browser-e2e', 'scripts', 'run_tide_journeys.py');
  const probe = String.raw`
import ast, json, sys
from pathlib import Path
from types import SimpleNamespace
source = ast.parse(Path(sys.argv[1]).read_text(encoding="utf-8"))
nodes = [node for node in source.body if isinstance(node, ast.FunctionDef) and node.name == "run" or isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == "JOURNEYS" for target in node.targets)]
namespace = {"Path": Path}
exec(compile(ast.Module(body=nodes, type_ignores=[]), sys.argv[1], "exec"), namespace)
names = namespace["JOURNEYS"]
assert list(names) == json.loads(sys.argv[2]), names
for selected in [list(names), [names[0]], [names[1]]]:
    navigations = []
    openings = []
    page = SimpleNamespace(goto=navigations.append)
    browser = SimpleNamespace(new_page=lambda: page, close=lambda: None)
    class Playwright:
        def __enter__(self): return SimpleNamespace(chromium=SimpleNamespace(launch=lambda **kwargs: browser))
        def __exit__(self, *args): pass
    def open_target(*args):
        openings.append("opened")
        assert len(openings) <= len(selected), "fixture reopened after the final journey"
    namespace.update(sync_playwright=Playwright, open_target=open_target,
        save_reading=lambda page: {"name": names[0], "ok": True},
        refuse_blank=lambda page: {"name": names[1], "ok": True})
    result = namespace["run"]("fixture", sys.executable, journeys=selected)
    assert len(openings) == len(selected), openings
    assert navigations == ["about:blank"] * (len(selected) - 1), navigations
    assert len(result["journeys"]) == len(selected), result
print("journey declarations and navigation verified")
`;
  const result = spawnSync('python', ['-I', '-c', probe, driverPath, JSON.stringify(tideJourneys.map((journey) => journey.name))], { encoding: 'utf8', timeout: 15000 });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('a pair just under 4.5 is not rounded up into a passing gate', () => {
  const result = run(['--foreground', '#151515', '--background', '#7e7e7e', '--threshold', '4.5']);
  assert.notEqual(result.status, 0);
  const report = JSON.parse(result.stdout);
  assert.equal(report.meets.requested, false);
  assert.ok(report.ratio < 4.5, 'rounded ratio ' + report.ratio + ' must not read as meeting 4.5');
});

test('a pair just under 3 is not rounded up into a passing boundary gate', () => {
  const result = run(['--foreground', '#1b1b1b', '--background', '#666666', '--threshold', '3']);
  assert.notEqual(result.status, 0);
  const report = JSON.parse(result.stdout);
  assert.equal(report.meets.requested, false);
  assert.ok(report.ratio < 3, 'rounded ratio ' + report.ratio + ' must not read as meeting 3');
});

test('an unknown flag is rejected and does not drop the requested gate', () => {
  const result = run(['--foreground', '#777777', '--background', '#FFFFFF', '--threshhold', '4.5']);
  assert.notEqual(result.status, 0);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /contrast-ratio:/);
});

test('the fixture server binds to loopback and serves the page', async () => {
  const child = spawn(process.execPath, [path.join(root, 'skills', 'browser-e2e', 'scripts', 'serve-fixture.mjs')], {
    cwd: root,
    env: { PATH: process.env.PATH, SystemRoot: process.env.SystemRoot },
    stdio: ['pipe', 'pipe', 'pipe'],
  });
  let output = '';
  child.stdout.on('data', (chunk) => { output += chunk; });
  try {
    const match = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`no loopback line: ${output}`)), 5000);
      child.stdout.on('data', () => {
        const found = /listening http:\/\/127\.0\.0\.1:(\d+)/.exec(output);
        if (found) { clearTimeout(timer); resolve(found); }
      });
      child.on('exit', (code) => reject(new Error(`server exited ${code}`)));
    });
    const response = await fetch(`http://127.0.0.1:${match[1]}/`);
    assert.equal(response.status, 200);
    assert.match(await response.text(), /Tide time is required\./);
  } finally {
    child.stdin.end();
    await new Promise((resolve) => child.on('exit', resolve));
  }
});

test('removing a journey or its fixture role makes the journey runner report a failure', { skip: browserUnavailable() }, async () => {
  const runnerPath = path.join(root, 'skills', 'browser-e2e', 'scripts', 'run-tide-journeys.mjs');
  const runner = await import(pathToFileURL(runnerPath).href);
  const fixture = path.join(root, 'tests', 'fixtures', 'capability', 'design-browser-page.html');
  const served = await runner.runTideJourneys({ fixturePath: 'http://127.0.0.1:9/', executablePath: chromiumPath() });
  assert.equal(served.ok, false);
  assert.match(served.failures.join(String.fromCharCode(10)), /refused|unavailable/);

  const positive = await runner.runTideJourneys({ fixturePath: fixture, executablePath: chromiumPath() });
  assert.equal(positive.ok, true, JSON.stringify(positive));
  assert.equal(positive.journeys.find((journey) => journey.name === 'saves a tide reading').ok, true);
  assert.equal(positive.journeys.find((journey) => journey.name === 'refuses a blank tide time').ok, true);

  const removed = runner.tideJourneys.filter((journey) => journey.name !== 'refuses a blank tide time');
  const missing = await runner.runTideJourneys({ fixturePath: fixture, executablePath: chromiumPath(), journeys: removed });
  assert.equal(missing.ok, false);
  assert.match(missing.failures.join('\n'), /refuses a blank tide time/);

  const broken = await runner.runTideJourneys({
    fixturePath: fixture,
    executablePath: chromiumPath(),
    html: readFileSync(fixture, 'utf8').replace('Tide time is required.', 'Something else happened.'),
  });
  assert.equal(broken.ok, false);
  assert.equal(broken.journeys.find((journey) => journey.name === 'refuses a blank tide time').ok, false);

  const seeded = await runner.runTideJourneys({ fixturePath: fixture, executablePath: chromiumPath(), seedDefect: true });
  assert.equal(seeded.ok, false);
  const refusal = seeded.journeys.find((journey) => journey.name === 'refuses a blank tide time');
  assert.equal(refusal.ok, false);
  assert.match(refusal.detail, /items=\[''\]/);
});

test('a missing Python interpreter is a named dependency failure, not an exited null', async () => {
  const runnerPath = path.join(root, 'skills', 'browser-e2e', 'scripts', 'run-tide-journeys.mjs');
  const runner = await import(pathToFileURL(runnerPath).href);
  const fixture = path.join(root, 'tests', 'fixtures', 'capability', 'design-browser-page.html');
  assert.throws(
    () => runner.runTideJourneys({ fixturePath: fixture, executablePath: 'C:\\missing\\chrome.exe', pythonPath: 'C:\\missing\\python.exe' }),
    (error) => {
      assert.match(error.message, /missing dependency: Python/);
      assert.doesNotMatch(error.message, /exited null/);
      assert.doesNotMatch(error.message, /KeyError/);
      return true;
    },
  );
});

test('a Python without Playwright is a named dependency failure, not a traceback', { skip: pythonUnavailable() }, async () => {
  const runnerPath = path.join(root, 'skills', 'browser-e2e', 'scripts', 'run-tide-journeys.mjs');
  const runner = await import(pathToFileURL(runnerPath).href);
  const fixture = path.join(root, 'tests', 'fixtures', 'capability', 'design-browser-page.html');
  assert.throws(
    () => runner.runTideJourneys({
      fixturePath: fixture,
      executablePath: 'C:\\missing\\chrome.exe',
      pythonPath: 'python',
      pythonArgs: ['-I', '-S'],
    }),
    (error) => {
      assert.match(error.message, /missing dependency: Python Playwright/);
      assert.doesNotMatch(error.message, /Traceback/);
      assert.doesNotMatch(error.message, /ModuleNotFoundError/);
      return true;
    },
  );
});

test('the installed Chromium revision is chosen numerically, not by directory name', (t) => {
  const rootDir = mkdtempSync(path.join(tmpdir(), 'design-browser-chromium-order-'));
  t.after(() => rmSync(rootDir, { recursive: true, force: true }));
  mkdirSync(path.join(rootDir, 'chromium-9', 'chrome-win64'), { recursive: true });
  mkdirSync(path.join(rootDir, 'chromium-1234', 'chrome-win64'), { recursive: true });
  const chosen = chromiumPath(rootDir);
  assert.equal(chosen, path.join(rootDir, 'chromium-1234', 'chrome-win64', 'chrome.exe'));
});

test('a missing Chromium executable is a named dependency failure, not a KeyError', async () => {
  const runnerPath = path.join(root, 'skills', 'browser-e2e', 'scripts', 'run-tide-journeys.mjs');
  const runner = await import(pathToFileURL(runnerPath).href);
  const fixture = path.join(root, 'tests', 'fixtures', 'capability', 'design-browser-page.html');
  assert.throws(
    () => runner.runTideJourneys({ fixturePath: fixture }),
    (error) => {
      assert.match(error.message, /missing dependency: Chromium/);
      assert.doesNotMatch(error.message, /KeyError/);
      assert.doesNotMatch(error.message, /exited null/);
      return true;
    },
  );
});

test('a PATH-resolvable interpreter name other than python is accepted', { skip: pythonUnavailable() }, async (t) => {
  const runnerPath = path.join(root, 'skills', 'browser-e2e', 'scripts', 'run-tide-journeys.mjs');
  const runner = await import(pathToFileURL(runnerPath).href);
  const fixture = path.join(root, 'tests', 'fixtures', 'capability', 'design-browser-page.html');
  const directory = mkdtempSync(path.join(tmpdir(), 'design-browser-python-name-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const located = spawnSync('python', ['-I', '-c', 'import sys; print(sys.executable)'], { encoding: 'utf8', timeout: 15000 });
  assert.equal(located.status, 0, located.stderr);
  const executable = located.stdout.trim();
  const alias = path.join(directory, path.basename(executable, '.exe') === 'python' ? 'tidepython.exe' : 'tidepython');
  const copied = spawnSync('cmd.exe', ['/d', '/c', 'copy', '/y', executable, alias], { encoding: 'utf8', timeout: 15000 });
  assert.equal(copied.status, 0, copied.stderr);
  const previous = process.env.PATH;
  process.env.PATH = directory + path.delimiter + previous;
  try {
    const report = runner.runTideJourneys({
      fixturePath: fixture,
      executablePath: path.join(directory, 'missing-chrome.exe'),
      pythonPath: 'tidepython',
    });
    assert.equal(report.ok, false);
    assert.match(report.failures.join('\n'), /missing dependency: Chromium executable was not found/);
  } finally {
    process.env.PATH = previous;
  }
});

function pythonUnavailable() {
  const python = spawnSync('python', ['-I', '-c', 'import sys'], { encoding: 'utf8', timeout: 15000 });
  if (python.error && python.error.code === 'ENOENT') return 'missing dependency: Python interpreter was not found on PATH';
  if (python.status !== 0) return 'missing dependency: Python interpreter did not run';
  return false;
}

function browserUnavailable() {
  const python = spawnSync('python', ['-I', '-c', 'import playwright'], { encoding: 'utf8', timeout: 15000 });
  if (python.error && python.error.code === 'ENOENT') return 'missing dependency: Python interpreter was not found on PATH';
  if (python.status === null) return 'missing dependency: Python interpreter did not exit';
  if (python.status !== 0) return 'missing dependency: Python Playwright is not importable';
  if (!chromiumPath(process.env.LOCALAPPDATA && path.join(process.env.LOCALAPPDATA, 'ms-playwright'))) return 'missing dependency: Chromium executable was not found';
  return false;
}

function chromiumPath(rootDir = process.env.LOCALAPPDATA && path.join(process.env.LOCALAPPDATA, 'ms-playwright')) {
  if (!rootDir || !existsSync(rootDir)) return undefined;
  const installs = readdirSync(rootDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && /^chromium-\d+$/.test(entry.name))
    .map((entry) => entry.name)
    .sort((left, right) => Number(left.slice('chromium-'.length)) - Number(right.slice('chromium-'.length)));
  const latest = installs.at(-1);
  return latest ? path.join(rootDir, latest, 'chrome-win64', 'chrome.exe') : undefined;
}
