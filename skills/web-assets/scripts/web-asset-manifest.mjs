import { writeFileSync } from 'node:fs';

const values = readArgs(process.argv.slice(2));
if (!/^#[0-9a-fA-F]{6}$/.test(values.color)) {
  process.stderr.write('color must be a 6-digit hex value\n');
  process.exit(1);
}
const sizes = ['16x16', '32x32', '180x180', '192x192', '512x512'];
const manifest = {
  name: values.name,
  backgroundColor: values.color,
  icons: sizes.map((size) => ({ src: `icon-${size}.png`, sizes: size, type: 'image/png' })),
};
writeFileSync(values.output, `${JSON.stringify(manifest, null, 2)}\n`);

function readArgs(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    result[argv[index].replace(/^--/, '')] = argv[index + 1];
  }
  for (const name of ['name', 'color', 'output']) {
    if (!result[name]) {
      process.stderr.write(`missing --${name}\n`);
      process.exit(1);
    }
  }
  return result;
}
