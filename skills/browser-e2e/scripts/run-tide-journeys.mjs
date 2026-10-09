import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const script = path.join(path.dirname(fileURLToPath(import.meta.url)), 'run_tide_journeys.py');

export const tideJourneys = [
  { name: 'saves a tide reading' },
  { name: 'refuses a blank tide time' },
];

export function runTideJourneys({ fixturePath, executablePath, html, journeys, seedDefect = false, pythonPath = 'python', pythonArgs = ['-I'] } = {}) {
  if (!executablePath) {
    throw new Error('missing dependency: Chromium executable path was not provided');
  }
  const result = spawnSync(pythonPath, [...pythonArgs, script], {
    input: JSON.stringify({
      fixture: fixturePath,
      executable: executablePath,
      html,
      journeys: journeys && journeys.map((journey) => journey.name),
      seedDefect,
    }),
    encoding: 'utf8',
    timeout: 30000,
  });
  if (result.error) {
    const detail = result.error.code === 'ENOENT'
      ? 'was not found on PATH'
      : 'could not be started (' + result.error.code + ')';
    throw new Error('missing dependency: Python interpreter "' + pythonPath + '" ' + detail);
  }
  if (result.status !== 0) {
    throw new Error(result.stderr || 'journey runner exited ' + result.status);
  }
  return JSON.parse(result.stdout);
}
