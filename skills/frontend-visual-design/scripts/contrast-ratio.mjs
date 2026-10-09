const values = readArgs(process.argv.slice(2));
const ratio = contrastRatio(values.foreground, values.background);
const meets = { text: ratio >= 4.5, boundary: ratio >= 3 };
if (values.threshold !== null) meets.requested = ratio >= values.threshold;
process.stdout.write(`${JSON.stringify({
  foreground: values.foreground,
  background: values.background,
  ratio: roundRatio(ratio),
  threshold: values.threshold,
  meets,
})}\n`);
if (values.threshold !== null && !meets.requested) process.exitCode = 2;

function readArgs(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    const name = argv[index];
    if (!name?.startsWith('--') || argv[index + 1] === undefined) fail(`missing value for ${name ?? 'argument'}`);
    result[name.slice(2)] = argv[index + 1];
  }
  return {
    foreground: normalizeColor(result.foreground, 'foreground'),
    background: normalizeColor(result.background, 'background'),
    threshold: normalizeThreshold(result.threshold),
  };
}

function normalizeColor(value, name) {
  if (typeof value !== 'string' || !/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(value)) fail(`${name} must be #RGB or #RRGGBB`);
  const hex = value.slice(1);
  const full = hex.length === 3 ? hex.replace(/./g, (digit) => digit + digit) : hex;
  return `#${full.toUpperCase()}`;
}

function normalizeThreshold(value) {
  if (value === undefined) return null;
  if (!['3', '4.5'].includes(value)) fail('threshold must be 3 or 4.5');
  return Number(value);
}

function contrastRatio(foreground, background) {
  const lighter = Math.max(relativeLuminance(foreground), relativeLuminance(background));
  const darker = Math.min(relativeLuminance(foreground), relativeLuminance(background));
  return (lighter + 0.05) / (darker + 0.05);
}

function relativeLuminance(color) {
  const channels = [1, 3, 5].map((offset) => Number.parseInt(color.slice(offset, offset + 2), 16) / 255);
  const linear = channels.map((channel) => (channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4));
  return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
}

function roundRatio(ratio) {
  return Math.round(ratio * 100) / 100;
}

function fail(message) {
  process.stderr.write(`contrast-ratio: ${message}\n`);
  process.exit(1);
}
