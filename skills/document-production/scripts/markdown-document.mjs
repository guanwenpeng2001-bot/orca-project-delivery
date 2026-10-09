import { readFileSync, renameSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

const values = readArgs(process.argv.slice(2));
try {
  const document = JSON.parse(readFileSync(values.input, 'utf8'));
  const lines = render(document);
  const temporary = join(dirname(values.output), '.document-depth-' + process.pid + '-' + Date.now() + '.md');
  writeFileSync(temporary, `${lines.join('\n')}\n`);
  renameSync(temporary, values.output);
} catch (error) {
  process.stderr.write(`${error.message}\n`);
  process.exit(1);
}

function render(document) {
  if (!document || typeof document.title !== 'string' || !document.title.trim()) {
    throw new Error('title must be nonempty text');
  }
  if (!Array.isArray(document.blocks)) {
    throw new Error('blocks must be a list');
  }
  const lines = ['# ' + document.title];
  for (const block of document.blocks) {
    lines.push('', ...renderBlock(block));
  }
  return lines;
}

function renderBlock(block) {
  if (!block || typeof block !== 'object') {
    throw new Error('unsupported block');
  }
  if (block.type === 'bullets') {
    return items(block).map((item) => `- ${item}`);
  }
  if (block.type === 'list') {
    if (block.ordered !== true) {
      throw new Error('list blocks must set ordered true');
    }
    return items(block).map((item, index) => `${index + 1}. ${item}`);
  }
  if (block.type === 'heading') {
    return [`## ${text(block, 'text')}`];
  }
  if (block.type === 'paragraph') {
    return [text(block, 'text')];
  }
  if (block.type === 'table') {
    return renderTable(block);
  }
  throw new Error(`unsupported block ${block.type}`);
}

function items(block) {
  if (!Array.isArray(block.items) || block.items.some((item) => typeof item !== 'string' || !item.trim())) {
    throw new Error(`${block.type} items must be nonempty text`);
  }
  return block.items;
}

function text(block, field) {
  const value = block[field];
  if (typeof value !== 'string' || !value.trim()) {
    throw new Error(`${block.type} ${field} must be nonempty text`);
  }
  return value;
}

function renderTable(block) {
  if (!Array.isArray(block.columns) || !block.columns.length || block.columns.some((column) => typeof column !== 'string' || !column.trim())) {
    throw new Error('table columns must be nonempty text');
  }
  if (!Array.isArray(block.rows)) {
    throw new Error('table rows must be a list');
  }
  const width = block.columns.length;
  block.rows.forEach((row, index) => {
    if (!Array.isArray(row) || row.length !== width) {
      throw new Error(`row ${index + 1} has ${Array.isArray(row) ? row.length : 0} cells but ${width} columns`);
    }
    row.forEach((cellValue) => {
      if (typeof cellValue !== 'string') {
        throw new Error(`row ${index + 1} cells must be text`);
      }
    });
  });
  const header = block.columns.map(escapeCell).join(' | ');
  const divider = block.columns.map(() => '---').join(' | ');
  const body = block.rows.map((row) => row.map(escapeCell).join(' | '));
  return [`| ${header} |`, `| ${divider} |`, ...body.map((row) => `| ${row} |`)];
}

function escapeCell(value) {
  const slash = String.fromCharCode(92);
  const escaped = value.split(slash).join(slash + slash).split('|').join(slash + '|');
  return escaped.replace(/\r?\n/g, ' ');
}

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
