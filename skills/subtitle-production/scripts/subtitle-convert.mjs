import { readFileSync, renameSync, writeFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import path from 'node:path';

const values = readArgs(process.argv.slice(2));
if (!['srt', 'vtt'].includes(values.to)) fail(`--to must be srt or vtt, got ${values.to}`);

const decoded = decodeUtf8(readFileSync(values.input));
const cues = values.to === 'vtt' ? parseSrt(decoded) : parseVtt(decoded);
validateCues(cues);

const body = values.to === 'vtt' ? renderVtt(cues) : renderSrt(cues);
writeAtomically(values.output, body);
process.stdout.write(`${JSON.stringify({
  input: values.input,
  output: values.output,
  format: values.to,
  cues: cues.filter((cue) => cue.start !== null).length,
  warnings: cues.flatMap((cue) => cue.warnings),
})}\n`);

function readArgs(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    const name = argv[index];
    if (!name?.startsWith('--') || argv[index + 1] === undefined) fail(`missing value for ${name ?? 'argument'}`);
    result[name.replace(/^--/, '')] = argv[index + 1];
  }
  for (const name of ['input', 'output', 'to']) {
    if (!result[name]) fail(`missing --${name}`);
  }
  return result;
}

function decodeUtf8(bytes) {
  if (bytes.includes(0)) fail('encoding is not utf-8: file contains NUL bytes');
  const text = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  return text.replace(/^﻿/, '').replace(/\r\n?/g, '\n');
}

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

function parseSrt(text) {
  return blocks(text).map((block) => {
    const lines = block.split('\n');
    const timingAt = lines.findIndex((line) => line.includes('-->'));
    if (timingAt < 0) fail('malformed srt: a block has no timing line');
    const [start, end] = readTiming(lines[timingAt], ',');
    const payload = lines.slice(timingAt + 1);
    if (payload.length === 0 || payload.every((line) => line.trim() === '')) fail('empty cue text');
    return { start, end, text: payload.join('\n'), warnings: [] };
  });
}

function parseVtt(text) {
  if (!/^WEBVTT(\s|$)/.test(text)) fail('malformed webvtt: missing WEBVTT header');
  const body = text.replace(/^WEBVTT[^\n]*\n/, '');
  const cues = [];
  for (const block of blocks(body)) {
    const kind = block.split(/[\s\n]/, 1)[0];
    if (['STYLE', 'REGION'].includes(kind)) fail(`unsupported webvtt block: ${kind}`);
    if (kind === 'NOTE') {
      cues.push({ start: null, end: null, text: '', warnings: ['NOTE block skipped'] });
    } else {
    const lines = block.split('\n');
    const timingAt = lines.findIndex((line) => line.includes('-->'));
    if (timingAt < 0) fail('malformed webvtt: a block has no timing line');
    if (timingAt > 1) fail('malformed webvtt: unexpected lines before the timing line');
    const warnings = [];
    if (timingAt === 1) warnings.push(`cue identifier "${lines[0]}" has no srt equivalent`);
    const timing = lines[timingAt].split('-->');
    if (timing[1].trim().split(/\s+/).length > 1) fail('unsupported webvtt cue setting on the timing line');
    const payload = lines.slice(timingAt + 1);
    if (payload.some((line) => /<v[\s>]/.test(line))) fail('unsupported webvtt voice span');
    if (payload.length === 0 || payload.every((line) => line.trim() === '')) fail('empty cue text');
    cues.push({
      start: readTimestamp(timing[0].trim(), '.'),
      end: readTimestamp(timing[1].trim(), '.'),
      text: payload.join('\n'),
      warnings,
    });
    }
  }
  return cues;
}

function blocks(text) {
  return text.split('\n\n').map((block) => block.trim()).filter((block) => block !== '');
}

function readTiming(line, separator) {
  const parts = line.split('-->');
  if (parts.length !== 2) fail(`malformed timestamp line: ${line}`);
  return parts.map((part) => readTimestamp(part.trim(), separator));
}

function readTimestamp(value, separator) {
  const match = new RegExp(`^(\\d{2,}):(\\d{2}):(\\d{2})\\${separator}(\\d{3})$`).exec(value);
  if (!match) fail(`malformed timestamp: ${value}`);
  const [, hours, minutes, seconds, millis] = match.map(Number);
  if (minutes > 59 || seconds > 59) fail(`malformed timestamp: ${value}`);
  return ((hours * 60 + minutes) * 60 + seconds) * 1000 + millis;
}

function validateCues(cues) {
  let previous = -1;
  for (const cue of cues) {
    if (cue.start !== null && cue.end <= cue.start) fail(`cue timing must end after it starts: ${cue.start} -> ${cue.end}`);
    if (cue.start !== null && cue.start < previous) fail(`cues are out of time order at ${cue.start}`);
    if (cue.start !== null && cue.start < previousEnd(cues, cue)) fail(`cue overlap at ${cue.start}`);
    if (cue.start !== null) previous = cue.start;
  }
}

function previousEnd(cues, cue) {
  const index = cues.indexOf(cue);
  for (let earlier = index - 1; earlier >= 0; earlier -= 1) {
    if (cues[earlier].start !== null) return cues[earlier].end;
  }
  return -1;
}

function renderSrt(cues) {
  const rendered = cues.filter((cue) => cue.start !== null).map((cue, index) => (
    `${index + 1}\n${formatTimestamp(cue.start, ',')} --> ${formatTimestamp(cue.end, ',')}\n${cue.text}\n`
  ));
  return `${rendered.join('\n')}`;
}

function renderVtt(cues) {
  const rendered = cues.map((cue) => `${formatTimestamp(cue.start, '.')} --> ${formatTimestamp(cue.end, '.')}\n${cue.text}\n`);
  return `WEBVTT\n\n${rendered.join('\n')}`;
}

function formatTimestamp(millis, separator) {
  const hours = Math.floor(millis / 3600000);
  if (hours > 99) fail(`timestamp out of srt range: ${millis}`);
  const minutes = Math.floor(millis / 60000) % 60;
  const seconds = Math.floor(millis / 1000) % 60;
  const padded = [hours, minutes, seconds].map((part) => String(part).padStart(2, '0')).join(':');
  return `${padded}${separator}${String(millis % 1000).padStart(3, '0')}`;
}

function writeAtomically(output, body) {
  const temporary = path.join(path.dirname(output), `.${path.basename(output)}.${randomBytes(4).toString('hex')}.tmp`);
  writeFileSync(temporary, body);
  renameSync(temporary, output);
}
