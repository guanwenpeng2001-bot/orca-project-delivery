import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const fixtureRoot = path.join(root, 'tests', 'fixtures', 'capability');

function runScript(relativePath, args) {
  return spawnSync(process.execPath, [path.join(root, relativePath), ...args], {
    cwd: root,
    encoding: 'utf8',
    env: { PATH: process.env.PATH, SystemRoot: process.env.SystemRoot },
    timeout: 15000,
  });
}

function reportOf(result) {
  return JSON.parse(result.stdout);
}

const CONVERT = 'skills/subtitle-production/scripts/subtitle-convert.mjs';
const PRECHECK = 'skills/code-video-production/scripts/composition-check.mjs';
const COMPARE = 'skills/media-transcoding/scripts/probe-compare.mjs';

let directory;

test.before(() => {
  directory = mkdtempSync(path.join(tmpdir(), 'subtitle-media-'));
});

test.after(() => {
  rmSync(directory, { recursive: true, force: true });
});

function writeTemp(name, contents) {
  const file = path.join(directory, name);
  writeFileSync(file, contents);
  return file;
}

// --- SRT and WebVTT conversion ------------------------------------------------

const SAMPLE_SRT = [
  '1',
  '00:00:01,000 --> 00:00:02,500',
  'Harbor check',
  '',
  '2',
  '00:00:03,000 --> 00:00:04,000',
  'Second line',
  'continues',
  '',
].join('\n');

test('srt converts to webvtt with dot timestamps, a header, and renumbered cues', () => {
  const input = writeTemp('sample.srt', `﻿${SAMPLE_SRT.replaceAll('\n', '\r\n')}`);
  const output = path.join(directory, 'sample.vtt');
  const result = runScript(CONVERT, ['--input', input, '--output', output, '--to', 'vtt']);
  assert.equal(result.status, 0, result.stderr);
  const report = reportOf(result);
  assert.equal(report.format, 'vtt');
  assert.equal(report.cues, 2);
  assert.deepEqual(report.warnings, []);
  const written = readFileSync(output, 'utf8');
  assert.equal(written.includes('\r'), false);
  assert.match(written, /^WEBVTT\n\n00:00:01\.000 --> 00:00:02\.500\nHarbor check\n\n00:00:03\.000 --> 00:00:04\.000\nSecond line\ncontinues\n$/);
});

test('webvtt converts back to srt and a round trip keeps cue count and timing', () => {
  const vtt = writeTemp('round.vtt', 'WEBVTT\n\n00:00:01.000 --> 00:00:02.500\nHarbor check\n\n00:01:03.250 --> 00:01:04.000\nSecond line\ncontinues\n');
  const srt = path.join(directory, 'round.srt');
  const forward = runScript(CONVERT, ['--input', vtt, '--output', srt, '--to', 'srt']);
  assert.equal(forward.status, 0, forward.stderr);
  assert.equal(reportOf(forward).cues, 2);
  assert.match(readFileSync(srt, 'utf8'), /^1\n00:00:01,000 --> 00:00:02,500\nHarbor check\n\n2\n00:01:03,250 --> 00:01:04,000\nSecond line\ncontinues\n$/);

  const back = path.join(directory, 'round-back.vtt');
  const returned = runScript(CONVERT, ['--input', srt, '--output', back, '--to', 'vtt']);
  assert.equal(returned.status, 0, returned.stderr);
  assert.equal(readFileSync(back, 'utf8'), readFileSync(vtt, 'utf8'));
});

test('an overlapping cue is rejected and no output file is written', () => {
  const input = writeTemp('overlap.srt', '1\n00:00:01,000 --> 00:00:03,000\nFirst\n\n2\n00:00:02,000 --> 00:00:04,000\nSecond\n');
  const output = path.join(directory, 'overlap-out.vtt');
  writeFileSync(output, 'pre-existing');
  const result = runScript(CONVERT, ['--input', input, '--output', output, '--to', 'vtt']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /overlap/i);
  assert.equal(readFileSync(output, 'utf8'), 'pre-existing');
});

test('cues out of time order are rejected', () => {
  const input = writeTemp('unordered.srt', '1\n00:00:05,000 --> 00:00:06,000\nLater\n\n2\n00:00:01,000 --> 00:00:02,000\nEarlier\n');
  const output = path.join(directory, 'unordered-out.vtt');
  const result = runScript(CONVERT, ['--input', input, '--output', output, '--to', 'vtt']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /order/i);
  assert.throws(() => readFileSync(output));
});

test('a cue whose end is not after its start is rejected', () => {
  const input = writeTemp('zero.srt', '1\n00:00:02,000 --> 00:00:02,000\nNothing\n');
  const result = runScript(CONVERT, ['--input', input, '--output', path.join(directory, 'zero-out.vtt'), '--to', 'vtt']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /timing/i);
});

test('a timestamp that is not a timecode is rejected', () => {
  const input = writeTemp('badtime.srt', '1\n00:00:01,000 --> soon\nText\n');
  const result = runScript(CONVERT, ['--input', input, '--output', path.join(directory, 'badtime-out.vtt'), '--to', 'vtt']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /timestamp/i);
});

test('an empty cue is rejected', () => {
  const input = writeTemp('empty.srt', '1\n00:00:01,000 --> 00:00:02,000\n\n');
  const result = runScript(CONVERT, ['--input', input, '--output', path.join(directory, 'empty-out.vtt'), '--to', 'vtt']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /empty/i);
});

test('bytes that are not valid utf-8 are rejected instead of replaced', () => {
  const input = path.join(directory, 'latin1.srt');
  writeFileSync(input, Buffer.concat([
    Buffer.from('1\n00:00:01,000 --> 00:00:02,000\n'),
    Buffer.from([0x63, 0x61, 0x66, 0xe9]),
    Buffer.from('\n'),
  ]));
  const output = path.join(directory, 'latin1-out.vtt');
  const result = runScript(CONVERT, ['--input', input, '--output', output, '--to', 'vtt']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /encoding/i);
  assert.throws(() => readFileSync(output));
});

test('unsupported webvtt styling is reported by name and never silently dropped', () => {
  const styled = writeTemp('styled.vtt', 'WEBVTT\n\nSTYLE\n::cue { color: white; }\n\n00:00:01.000 --> 00:00:02.000\nPlain words\n');
  const styledResult = runScript(CONVERT, ['--input', styled, '--output', path.join(directory, 'styled-out.srt'), '--to', 'srt']);
  assert.notEqual(styledResult.status, 0);
  assert.match(styledResult.stderr, /unsupported/);
  assert.match(styledResult.stderr, /STYLE/);

  const positioned = writeTemp('positioned.vtt', 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000 align:start\nPlain words\n');
  const positionedOutput = path.join(directory, 'positioned-out.srt');
  const positionedResult = runScript(CONVERT, ['--input', positioned, '--output', positionedOutput, '--to', 'srt']);
  assert.notEqual(positionedResult.status, 0);
  assert.match(positionedResult.stderr, /cue setting/);
  assert.throws(() => readFileSync(positionedOutput));
});

test('a cue voice span is unsupported because srt cannot carry it', () => {
  const input = writeTemp('voice.vtt', 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n<v Narrator>Harbor\n');
  const result = runScript(CONVERT, ['--input', input, '--output', path.join(directory, 'voice-out.srt'), '--to', 'srt']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /voice/);
});

test('a cue identifier is preserved as a warning and the conversion still succeeds', () => {
  const input = writeTemp('identified.vtt', 'WEBVTT\n\nintro\n00:00:01.000 --> 00:00:02.000\nHarbor\n');
  const output = path.join(directory, 'identified-out.srt');
  const result = runScript(CONVERT, ['--input', input, '--output', output, '--to', 'srt']);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(reportOf(result).warnings, ['cue identifier "intro" has no srt equivalent']);
  assert.match(readFileSync(output, 'utf8'), /^1\n00:00:01,000 --> 00:00:02,000\nHarbor\n$/);
});

test('a NOTE block is skipped with a warning and does not become a cue', () => {
  const input = writeTemp('noted.vtt', 'WEBVTT\n\nNOTE\nthis is a comment\nspanning a second line\n\n00:00:01.000 --> 00:00:02.000\nHarbor\n');
  const output = path.join(directory, 'noted-out.srt');
  const result = runScript(CONVERT, ['--input', input, '--output', output, '--to', 'srt']);
  assert.equal(result.status, 0, result.stderr);
  const report = reportOf(result);
  assert.equal(report.cues, 1);
  assert.deepEqual(report.warnings, ['NOTE block skipped']);
});

test('an hours value above 99 is rejected because srt cannot express it', () => {
  const input = writeTemp('long.vtt', 'WEBVTT\n\n100:00:00.000 --> 100:00:01.000\nMuch later\n');
  const result = runScript(CONVERT, ['--input', input, '--output', path.join(directory, 'long-out.srt'), '--to', 'srt']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /range/i);
});

test('a missing argument exits non-zero', () => {
  const result = runScript(CONVERT, ['--input', path.join(fixtureRoot, 'subtitle-media-sample.srt')]);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /missing --/);
});

test('a webvtt timing line with an extra arrow is rejected and writes nothing', () => {
  const input = writeTemp('three.vtt', 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000 --> 00:00:09.000\nHarbor\n');
  const output = path.join(directory, 'three.srt');
  writeFileSync(output, 'pre-existing');
  const result = runScript(CONVERT, ['--input', input, '--output', output, '--to', 'srt']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /timestamp line/);
  assert.equal(readFileSync(output, 'utf8'), 'pre-existing');
});

test('a short-form webvtt timestamp converts and keeps the cue', () => {
  const input = writeTemp('short.vtt', 'WEBVTT\n\n00:01.000 --> 00:02.500\nHarbor\n');
  const output = path.join(directory, 'short.srt');
  const result = runScript(CONVERT, ['--input', input, '--output', output, '--to', 'srt']);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(reportOf(result).cues, 1);
  assert.match(readFileSync(output, 'utf8'), /^1\n00:00:01,000 --> 00:00:02,500\nHarbor\n$/);
});

test('hours above 99 are written for webvtt and rejected for srt', () => {
  const input = writeTemp('long-hours.srt', '1\n100:00:00,000 --> 100:00:01,000\nLater\n');
  const output = path.join(directory, 'long-hours.vtt');
  const result = runScript(CONVERT, ['--input', input, '--output', output, '--to', 'vtt']);
  assert.equal(result.status, 0, result.stderr);
  assert.match(readFileSync(output, 'utf8'), /100:00:00\.000 --> 100:00:01\.000\nLater\n$/);

  const back = path.join(directory, 'long-hours-back.srt');
  const rejected = runScript(CONVERT, ['--input', output, '--output', back, '--to', 'srt']);
  assert.notEqual(rejected.status, 0);
  assert.match(rejected.stderr, /range/i);
  assert.throws(() => readFileSync(back));
});

test('an empty source converts to an empty file and warns that it has no cues', () => {
  const input = writeTemp('empty-source.srt', '');
  const output = path.join(directory, 'empty-source.vtt');
  const result = runScript(CONVERT, ['--input', input, '--output', output, '--to', 'vtt']);
  assert.equal(result.status, 0, result.stderr);
  const report = reportOf(result);
  assert.equal(report.cues, 0);
  assert.deepEqual(report.warnings, ['source has no cues']);
  assert.equal(readFileSync(output, 'utf8'), 'WEBVTT\n\n');
});

test('trailing text on an srt timestamp is rejected and the destination stays untouched', () => {
  const end = writeTemp('end-junk.srt', '1\n00:00:01,000 --> 00:00:02,000 X1:0 X2:100 Y1:0 Y2:50\nText\n');
  const endOutput = path.join(directory, 'end-junk.vtt');
  writeFileSync(endOutput, 'pre-existing');
  const endResult = runScript(CONVERT, ['--input', end, '--output', endOutput, '--to', 'vtt']);
  assert.notEqual(endResult.status, 0);
  assert.match(endResult.stderr, /timestamp/i);
  assert.equal(readFileSync(endOutput, 'utf8'), 'pre-existing');

  const start = writeTemp('start-junk.srt', '1\n00:00:01,000 foo --> 00:00:02,000\nText\n');
  const startOutput = path.join(directory, 'start-junk.vtt');
  writeFileSync(startOutput, 'pre-existing');
  const startResult = runScript(CONVERT, ['--input', start, '--output', startOutput, '--to', 'vtt']);
  assert.notEqual(startResult.status, 0);
  assert.match(startResult.stderr, /timestamp/i);
  assert.equal(readFileSync(startOutput, 'utf8'), 'pre-existing');
});

test('a webvtt cue setting is still rejected and the destination stays untouched', () => {
  const input = writeTemp('setting-kept.vtt', 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000 align:start\nPlain words\n');
  const output = path.join(directory, 'setting-kept.srt');
  writeFileSync(output, 'pre-existing');
  const result = runScript(CONVERT, ['--input', input, '--output', output, '--to', 'srt']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /cue setting/);
  assert.equal(readFileSync(output, 'utf8'), 'pre-existing');
});

// --- Composition precheck -----------------------------------------------------

const SAMPLE_HTML = [
  '<!doctype html>',
  '<main data-composition-id="code-change" data-start="0" data-duration="10" data-width="1280" data-height="720">',
  '<section data-start="0" data-duration="3" data-track-index="0">Failing check</section>',
  '<section data-start="3" data-duration="4" data-track-index="0">Apply once</section>',
  '<section data-start="7" data-duration="3" data-track-index="0">Passing check</section>',
  '</main>',
].join('\n');

test('the sample composition maps to 300 frames at the declared 30 fps', () => {
  const input = writeTemp('sample.html', SAMPLE_HTML);
  const result = runScript(PRECHECK, ['--input', input, '--fps', '30']);
  assert.equal(result.status, 0, result.stderr);
  const report = reportOf(result);
  assert.equal(report.compositionId, 'code-change');
  assert.equal(report.fps, 30);
  assert.equal(report.frames, 300);
  assert.equal(report.width, 1280);
  assert.equal(report.height, 720);
  assert.deepEqual(report.clips.map((clip) => [clip.startFrame, clip.endFrame]), [[0, 90], [90, 210], [210, 300]]);
  assert.deepEqual(report.warnings, []);
});

test('a root data-fps is used when no fps is declared on the command line', () => {
  const input = writeTemp('rooted-fps.html', SAMPLE_HTML.replace('data-height="720"', 'data-height="720" data-fps="30"'));
  const result = runScript(PRECHECK, ['--input', input]);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(reportOf(result).frames, 300);
});

test('a fractional frame rate maps frames exactly', () => {
  const html = '<main data-composition-id="ntsc" data-start="0" data-duration="1001" data-width="100" data-height="100">'
    + '<section data-start="0" data-duration="1001" data-track-index="0">Whole</section></main>';
  const input = writeTemp('ntsc.html', html);
  const result = runScript(PRECHECK, ['--input', input, '--fps', '24000/1001']);
  assert.equal(result.status, 0, result.stderr);
  const report = reportOf(result);
  assert.equal(report.fps, '24000/1001');
  assert.equal(report.frames, 24000);
  assert.deepEqual(report.clips[0], { id: null, track: 0, start: 0, duration: 1001, startFrame: 0, endFrame: 24000 });
});

test('an intentional cross-track overlap is accepted and only reported', () => {
  const html = SAMPLE_HTML.replace(
    '<section data-start="7" data-duration="3" data-track-index="0">Passing check</section>',
    '<section data-start="6" data-duration="4" data-track-index="1">Caption over the last state</section>',
  );
  const input = writeTemp('cross-track.html', html);
  const result = runScript(PRECHECK, ['--input', input, '--fps', '30']);
  assert.equal(result.status, 0, result.stderr);
  const report = reportOf(result);
  assert.equal(report.frames, 300);
  assert.equal(report.warnings.length, 1);
  assert.match(report.warnings[0], /cross-track overlap/);
});

test('a clip overlapping another on the same track is rejected', () => {
  const html = SAMPLE_HTML.replace('data-start="3" data-duration="4"', 'data-start="2" data-duration="4"');
  const input = writeTemp('same-track.html', html);
  const result = runScript(PRECHECK, ['--input', input, '--fps', '30']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /same track/);
});

test('touching clip boundaries share no frame and are accepted', () => {
  const result = runScript(PRECHECK, ['--input', writeTemp('touching.html', SAMPLE_HTML), '--fps', '30']);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(reportOf(result).warnings, []);
});

test('a gap inside a track is reported but a gap that covers the composition end is rejected', () => {
  const gapped = SAMPLE_HTML.replace('data-start="3" data-duration="4"', 'data-start="4" data-duration="3"');
  const reported = runScript(PRECHECK, ['--input', writeTemp('gapped.html', gapped), '--fps', '30']);
  assert.equal(reported.status, 0, reported.stderr);
  assert.match(reportOf(reported).warnings.join('\n'), /gap/);

  const short = SAMPLE_HTML.replace('data-duration="3" data-track-index="0">Passing', 'data-duration="2" data-track-index="0">Passing');
  const rejected = runScript(PRECHECK, ['--input', writeTemp('short.html', short), '--fps', '30']);
  assert.notEqual(rejected.status, 0);
  assert.match(rejected.stderr, /coverage/);
});

test('a duration that is not a whole number of frames is rejected', () => {
  const html = SAMPLE_HTML.replace('data-duration="10"', 'data-duration="10.016"');
  const result = runScript(PRECHECK, ['--input', writeTemp('fraction.html', html), '--fps', '30']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /frame/i);
});

function composition(duration, clips) {
  const sections = clips.map((clip) => (
    '<section data-start="' + clip.start + '" data-duration="' + clip.duration + '" data-track-index="' + clip.track + '">Scene</section>'
  ));
  return '<main data-composition-id="x" data-start="0" data-duration="' + duration + '" data-width="1920" data-height="1080">' + sections.join('') + '</main>';
}

test('a frame-aligned decimal duration is accepted at an integer rate', () => {
  const result = runScript(PRECHECK, ['--input', writeTemp('decimal.html', composition('4.1', [{ start: '0', duration: '4.1', track: '0' }])), '--fps', '30']);
  assert.equal(result.status, 0, result.stderr);
  const report = reportOf(result);
  assert.equal(report.frames, 123);
  assert.equal(report.clips[0].endFrame, 123);
});

test('a frame-aligned decimal duration is accepted at a rational rate', () => {
  const result = runScript(PRECHECK, ['--input', writeTemp('ntsc-decimal.html', composition('1.001', [{ start: '0', duration: '1.001', track: '0' }])), '--fps', '24000/1001']);
  assert.equal(result.status, 0, result.stderr);
  const report = reportOf(result);
  assert.equal(report.frames, 24);
  assert.equal(report.clips[0].endFrame, 24);
});

test('a clip that runs past the composition end is reported and still accepted', () => {
  const result = runScript(PRECHECK, ['--input', writeTemp('overrun.html', composition('10', [{ start: '0', duration: '20', track: '0' }])), '--fps', '30']);
  assert.equal(result.status, 0, result.stderr);
  const report = reportOf(result);
  assert.equal(report.frames, 300);
  assert.equal(report.clips[0].endFrame, 600);
  assert.match(report.warnings.join('\n'), /overrun/);
});

test('the shipped composition fixture maps to the same frames as the inlined sample', () => {
  const result = runScript(PRECHECK, ['--input', path.join(fixtureRoot, 'subtitle-media-sample.html'), '--fps', '30']);
  assert.equal(result.status, 0, result.stderr);
  const report = reportOf(result);
  assert.equal(report.frames, 300);
  assert.deepEqual(report.clips.map((clip) => [clip.startFrame, clip.endFrame]), [[0, 90], [90, 210], [210, 300]]);
  assert.deepEqual(report.warnings, []);
});

test('the shipped probe fixtures compare inside one frame', () => {
  const result = runScript(COMPARE, [
    '--source', path.join(fixtureRoot, 'subtitle-media-source-probe.json'),
    '--output', path.join(fixtureRoot, 'subtitle-media-output-probe.json'),
    '--width', '640',
    '--height', '360',
  ]);
  assert.equal(result.status, 0, result.stderr);
  const report = reportOf(result);
  assert.equal(report.matched, true);
  assert.equal(report.video.width, 640);
  assert.equal(report.video.height, 360);
  assert.ok(report.durationDelta <= report.tolerance);
});

test('a composition without a declared frame rate is rejected', () => {
  const result = runScript(PRECHECK, ['--input', writeTemp('nofps.html', SAMPLE_HTML)]);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /fps/i);
});

test('a second composition root is rejected as outside the grammar', () => {
  const html = `${SAMPLE_HTML}\n<main data-composition-id="other" data-start="0" data-duration="1" data-width="10" data-height="10"></main>`;
  const result = runScript(PRECHECK, ['--input', writeTemp('two.html', html), '--fps', '30']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /grammar|composition/i);
});

test('a relative time expression is rejected as outside the grammar', () => {
  const html = SAMPLE_HTML.replace('data-start="3"', 'data-start="intro + 3"');
  const result = runScript(PRECHECK, ['--input', writeTemp('relative.html', html), '--fps', '30']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /grammar/);
});

// --- ffprobe comparison -------------------------------------------------------

function probePair(name, source, output) {
  const sourceFile = writeTemp(`${name}-source.json`, JSON.stringify(source));
  const outputFile = writeTemp(`${name}-output.json`, JSON.stringify(output));
  return runScript(COMPARE, ['--source', sourceFile, '--output', outputFile]);
}

const SOURCE_PROBE = {
  streams: [
    { codec_type: 'video', codec_name: 'h264', width: 1280, height: 720, avg_frame_rate: '30/1' },
    { codec_type: 'audio', codec_name: 'aac' },
  ],
  format: { duration: '3.000000' },
};

test('a scaled output inside tolerance matches', () => {
  const output = {
    streams: [
      { codec_type: 'video', codec_name: 'h264', width: 640, height: 360, avg_frame_rate: '30/1' },
      { codec_type: 'audio', codec_name: 'aac' },
    ],
    format: { duration: '3.020000' },
  };
  const sourceFile = writeTemp('scaled-source.json', JSON.stringify(SOURCE_PROBE));
  const outputFile = writeTemp('scaled-output.json', JSON.stringify(output));
  const result = runScript(COMPARE, ['--source', sourceFile, '--output', outputFile, '--width', '640', '--height', '360']);
  assert.equal(result.status, 0, result.stderr);
  const report = reportOf(result);
  assert.equal(report.matched, true);
  assert.equal(report.video.frameRate, 30);
  assert.equal(report.audio.present, true);
});

test('a rational frame rate equal to its decimal form matches', () => {
  const output = structuredClone(SOURCE_PROBE);
  output.streams[0].avg_frame_rate = '30000/1001';
  const source = structuredClone(SOURCE_PROBE);
  source.streams[0].avg_frame_rate = '29.970';
  const result = probePair('rational', source, output);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(reportOf(result).video.frameRate, 30000 / 1001);
});

test('a duration beyond the one-frame tolerance is rejected', () => {
  const output = structuredClone(SOURCE_PROBE);
  output.format.duration = '3.100000';
  const result = probePair('drift', SOURCE_PROBE, output);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /duration/);
});

test('a missing audio stream is reported instead of matched', () => {
  const output = structuredClone(SOURCE_PROBE);
  output.streams = output.streams.filter((stream) => stream.codec_type !== 'audio');
  const result = probePair('silent', SOURCE_PROBE, output);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /audio/);
});

test('a missing video stream is reported instead of matched', () => {
  const output = structuredClone(SOURCE_PROBE);
  output.streams = output.streams.filter((stream) => stream.codec_type !== 'video');
  const result = probePair('novisual', SOURCE_PROBE, output);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /video/);
});

test('expected dimensions are enforced when declared', () => {
  const output = structuredClone(SOURCE_PROBE);
  output.streams[0].width = 640;
  output.streams[0].height = 360;
  const sourceFile = writeTemp('sized-source.json', JSON.stringify(SOURCE_PROBE));
  const outputFile = writeTemp('sized-output.json', JSON.stringify(output));
  const wrong = runScript(COMPARE, ['--source', sourceFile, '--output', outputFile, '--width', '1280', '--height', '720']);
  assert.notEqual(wrong.status, 0);
  assert.match(wrong.stderr, /dimension/);
  const right = runScript(COMPARE, ['--source', sourceFile, '--output', outputFile, '--width', '640', '--height', '360']);
  assert.equal(right.status, 0, right.stderr);
});

test('a non-finite duration is rejected as malformed', () => {
  const output = structuredClone(SOURCE_PROBE);
  output.format.duration = 'NaN';
  const result = probePair('nan', SOURCE_PROBE, output);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /malformed|non-finite|duration/i);
});

test('an infinite frame rate is rejected as malformed', () => {
  const output = structuredClone(SOURCE_PROBE);
  output.streams[0].avg_frame_rate = '1/0';
  const result = probePair('infinite', SOURCE_PROBE, output);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /frame rate/i);
});

test('a probe without a streams array is rejected as malformed', () => {
  const result = probePair('broken', SOURCE_PROBE, { format: { duration: '3.0' } });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /malformed/);
});

test('tolerance overrides the one-frame default', () => {
  const output = structuredClone(SOURCE_PROBE);
  output.format.duration = '3.050000';
  const sourceFile = writeTemp('tolerant-source.json', JSON.stringify(SOURCE_PROBE));
  const outputFile = writeTemp('tolerant-output.json', JSON.stringify(output));
  const strict = runScript(COMPARE, ['--source', sourceFile, '--output', outputFile]);
  assert.notEqual(strict.status, 0);
  const loose = runScript(COMPARE, ['--source', sourceFile, '--output', outputFile, '--tolerance', '0.1']);
  assert.equal(loose.status, 0, loose.stderr);
});
