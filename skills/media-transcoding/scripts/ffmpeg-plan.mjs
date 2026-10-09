const values = readArgs(process.argv.slice(2));
for (const name of ['width', 'height', 'fps']) {
  if (!/^[1-9][0-9]*$/.test(values[name])) {
    process.stderr.write(`${name} must be a positive integer\n`);
    process.exit(1);
  }
}
const plan = {
  argv: [
    'ffmpeg', '-i', values.input, '-vf', `scale=${values.width}:${values.height}`, '-r', values.fps,
    '-c:v', 'libx264', '-crf', '20', '-c:a', 'aac', '-movflags', '+faststart', values.output,
  ],
  executed: false,
};
process.stdout.write(`${JSON.stringify(plan)}\n`);

function readArgs(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    result[argv[index].replace(/^--/, '')] = argv[index + 1];
  }
  for (const name of ['input', 'output', 'width', 'height', 'fps']) {
    if (!result[name]) {
      process.stderr.write(`missing --${name}\n`);
      process.exit(1);
    }
  }
  return result;
}
