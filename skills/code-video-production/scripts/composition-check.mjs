import { readFileSync } from 'node:fs';

const values = readArgs(process.argv.slice(2));
const html = readFileSync(values.input, 'utf8');
const composition = readComposition(html);
const fps = readFps(values.fps ?? composition.fps);
const frames = toFrames(composition.duration, fps);
const clips = composition.clips.map((clip) => ({ ...clip, ...frameSpan(clip, fps) }));

const warnings = [];
for (const track of groupByTrack(clips)) {
  const ordered = [...track].sort((left, right) => left.start - right.start);
  for (let index = 1; index < ordered.length; index += 1) {
    if (ordered[index].start < ordered[index - 1].end) {
      fail(`clips overlap on the same track ${ordered[index].track} at ${ordered[index].start}`);
    }
    if (ordered[index].start > ordered[index - 1].end) {
      warnings.push(`gap on track ${ordered[index].track} between ${ordered[index - 1].end} and ${ordered[index].start}`);
    }
  }
}
const coveredUntil = clips.reduce((latest, clip) => Math.max(latest, clip.end), 0);
if (coveredUntil < composition.duration) fail(`coverage ends at ${coveredUntil}, composition lasts ${composition.duration}`);
for (const clip of clips) {
  if (clip.end > composition.duration) {
    warnings.push(`clip overrun on track ${clip.track}: clip ends at ${clip.end}, composition lasts ${composition.duration}`);
  }
}
for (let index = 0; index < clips.length; index += 1) {
  for (let other = index + 1; other < clips.length; other += 1) {
    const [left, right] = [clips[index], clips[other]];
    if (left.track !== right.track && left.start < right.end && right.start < left.end) {
      warnings.push(`cross-track overlap between track ${left.track} and track ${right.track} at ${Math.max(left.start, right.start)}`);
    }
  }
}

process.stdout.write(`${JSON.stringify({
  compositionId: composition.id,
  fps: fps.denominator === 1 ? fps.numerator : fps.text,
  frames,
  width: composition.width,
  height: composition.height,
  clips: clips.map((clip) => ({
    id: clip.id, track: clip.track, start: clip.start, duration: clip.duration, startFrame: clip.startFrame, endFrame: clip.endFrame,
  })),
  warnings,
})}\n`);

function readArgs(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    const name = argv[index];
    if (!name?.startsWith('--') || argv[index + 1] === undefined) fail(`missing value for ${name ?? 'argument'}`);
    result[name.replace(/^--/, '')] = argv[index + 1];
  }
  if (!result.input) fail('missing --input');
  return result;
}

function readComposition(html) {
  const roots = [...html.matchAll(/<([a-zA-Z][\w:-]*)\b([^>]*\bdata-composition-id="[^"]*"[^>]*)>/g)];
  if (roots.length !== 1) fail(`grammar supports exactly one composition root, found ${roots.length}`);
  const root = attributes(roots[0][2]);
  const id = requirePlain(root, 'data-composition-id');
  const width = requireNumber(root, 'data-width');
  const height = requireNumber(root, 'data-height');
  const duration = requireNumber(root, 'data-duration');
  if (root['data-start'] !== '0') fail('grammar requires the composition root data-start to be 0');
  const body = html.slice(roots[0].index);
  const clips = [...body.matchAll(/<([a-zA-Z][\w:-]*)\b([^>]*\bdata-start="[^"]*"[^>]*)>/g)]
    .map((match) => attributes(match[2]))
    .filter((attrs) => attrs['data-composition-id'] === undefined)
    .map((attrs) => ({
      id: attrs.id ?? null,
      track: requireInteger(attrs, 'data-track-index'),
      start: requireNumber(attrs, 'data-start'),
      duration: requireNumber(attrs, 'data-duration'),
    }));
  return { id, width, height, duration, fps: root['data-fps'] ?? null, clips };
}

function attributes(text) {
  const result = {};
  for (const match of text.matchAll(/([:@\w-]+)="([^"]*)"/g)) result[match[1]] = match[2];
  for (const declared of ['data-start', 'data-duration', 'data-track-index', 'data-fps']) {
    if (result[declared] !== undefined && !/^-?\d+(\.\d+)?$/.test(result[declared]) && !/^\d+\/\d+$/.test(result[declared])) {
      fail(`grammar accepts only plain numbers, found ${declared}="${result[declared]}"`);
    }
  }
  return result;
}

function requirePlain(attrs, name) {
  if (!attrs[name]) fail(`missing ${name}`);
  return attrs[name];
}

function requireNumber(attrs, name) {
  const value = Number(attrs[name]);
  if (!Number.isFinite(value) || value < 0) fail(`grammar accepts only plain numbers, found ${name}="${attrs[name]}"`);
  return value;
}

function requireInteger(attrs, name) {
  if (!/^\d+$/.test(attrs[name] ?? '')) fail(`missing whole-number ${name}`);
  return Number(attrs[name]);
}

function readFps(text) {
  if (text === null || text === undefined) fail('fps is not declared; pass --fps or set data-fps on the root');
  const match = /^(\d+)(?:\/(\d+))?$/.exec(text);
  if (!match) fail(`fps must be an integer or a rational, got ${text}`);
  const numerator = Number(match[1]);
  const denominator = match[2] === undefined ? 1 : Number(match[2]);
  if (numerator === 0 || denominator === 0) fail(`fps must be positive, got ${text}`);
  return { text, numerator, denominator };
}

function toFrames(seconds, fps) {
  const frames = seconds * fps.numerator / fps.denominator;
  const nearest = Math.round(frames);
  // Decimal seconds are not exact in binary, so a genuinely frame-aligned
  // duration can land a fraction of a ULP off an integer. The drift measured
  // across real rates stays under 1e-12 frames, while the smallest authoring
  // miss (a millisecond) is thousandths of a frame, so 1e-6 separates them.
  if (Math.abs(frames - nearest) > 1e-6) fail(`duration ${seconds} is not a whole number of frames at ${fps.text} fps`);
  return nearest;
}

function frameSpan(clip, fps) {
  const startFrame = toFrames(clip.start, fps);
  const end = clip.start + clip.duration;
  return { end, startFrame, endFrame: toFrames(end, fps) };
}

function groupByTrack(clips) {
  const tracks = new Map();
  for (const clip of clips) {
    if (!tracks.has(clip.track)) tracks.set(clip.track, []);
    tracks.get(clip.track).push(clip);
  }
  return [...tracks.values()];
}

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}
