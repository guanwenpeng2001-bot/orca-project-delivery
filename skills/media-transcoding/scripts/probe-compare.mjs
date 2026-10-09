import { readFileSync } from 'node:fs';

const values = readArgs(process.argv.slice(2));
const source = readProbe(values.source, 'source');
const output = readProbe(values.output, 'output');
const sourceVideo = requireStream(source, 'video');
const outputVideo = requireStream(output, 'video');
const sourceAudio = findStream(source, 'audio');
const outputAudio = findStream(output, 'audio');

const differences = [];
if (Boolean(sourceAudio) !== Boolean(outputAudio)) {
  differences.push(`audio ${sourceAudio ? 'missing from output' : 'unexpected in output'}`);
}
const sourceRate = frameRate(sourceVideo);
const outputRate = frameRate(outputVideo);
if (Math.abs(sourceRate - outputRate) > 0.001) differences.push(`frame rate ${sourceRate} differs from ${outputRate}`);

const expectedWidth = values.width === undefined ? sourceVideo.width : requireInteger(values.width, 'width');
const expectedHeight = values.height === undefined ? sourceVideo.height : requireInteger(values.height, 'height');
if (outputVideo.width !== expectedWidth || outputVideo.height !== expectedHeight) {
  differences.push(`dimension ${outputVideo.width}x${outputVideo.height} differs from expected ${expectedWidth}x${expectedHeight}`);
}

const tolerance = values.tolerance === undefined ? 1 / outputRate : requireFinite(values.tolerance, 'tolerance');
const durationDelta = Math.abs(duration(source) - duration(output));
if (durationDelta > tolerance) differences.push(`duration differs by ${durationDelta}, tolerance is ${tolerance}`);

if (differences.length > 0) fail(differences.join('\n'));
process.stdout.write(`${JSON.stringify({
  matched: true,
  video: { codec: outputVideo.codec_name, width: outputVideo.width, height: outputVideo.height, frameRate: outputRate },
  audio: { present: Boolean(outputAudio), codec: outputAudio?.codec_name ?? null },
  durationDelta,
  tolerance,
})}\n`);

function readArgs(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    const name = argv[index];
    if (!name?.startsWith('--') || argv[index + 1] === undefined) fail(`missing value for ${name ?? 'argument'}`);
    result[name.replace(/^--/, '')] = argv[index + 1];
  }
  for (const name of ['source', 'output']) {
    if (!result[name]) fail(`missing --${name}`);
  }
  return result;
}

function readProbe(file, label) {
  let parsed;
  try {
    parsed = JSON.parse(readFileSync(file, 'utf8'));
  } catch (error) {
    fail(`malformed ${label} probe: ${error.message}`);
  }
  if (!Array.isArray(parsed.streams)) fail(`malformed ${label} probe: streams must be an array`);
  return parsed;
}

function findStream(probe, type) {
  return probe.streams.find((stream) => stream.codec_type === type) ?? null;
}

function requireStream(probe, type) {
  const stream = findStream(probe, type);
  if (!stream) fail(`${type} stream missing`);
  return stream;
}

function frameRate(stream) {
  const match = /^(\d+)\/(\d+)$/.exec(stream.avg_frame_rate ?? '');
  const value = match ? Number(match[1]) / Number(match[2]) : Number(stream.avg_frame_rate);
  if (!Number.isFinite(value) || value <= 0) fail(`malformed frame rate: ${stream.avg_frame_rate}`);
  return value;
}

function duration(probe) {
  const value = Number(probe.format?.duration);
  if (!Number.isFinite(value) || value < 0) fail(`malformed non-finite duration: ${probe.format?.duration}`);
  return value;
}

function requireFinite(text, name) {
  const value = Number(text);
  if (!Number.isFinite(value) || value < 0) fail(`${name} must be a non-negative finite number`);
  return value;
}

function requireInteger(text, name) {
  if (!/^[1-9]\d*$/.test(text)) fail(`${name} must be a positive integer`);
  return Number(text);
}

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}
