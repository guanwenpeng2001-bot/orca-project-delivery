import { readFileSync, writeFileSync } from 'node:fs';

const values = readArgs(process.argv.slice(2));
const document = JSON.parse(readFileSync(values.input, 'utf8'));
const lines = [`# ${document.title}`, ''];
for (const block of document.blocks) {
  if (block.type !== 'bullets') {
    process.stderr.write(`unsupported block ${block.type}\n`);
    process.exit(1);
  }
  lines.push(...block.items.map((item) => `- ${item}`));
}
writeFileSync(values.output, `${lines.join('\n')}\n`);

function readArgs(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    result[argv[index].replace(/^--/, '')] = argv[index + 1];
  }
  for (const name of ['input', 'output']) {
    if (!result[name]) {
      process.stderr.write(`missing --${name}\n`);
      process.exit(1);
    }
  }
  return result;
}
