import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const fixture = path.join(root, 'tests', 'fixtures', 'capability', 'design-browser-page.html');
const port = Number(process.argv[2] ?? 0);

const server = createServer(async (request, response) => {
  if (request.url !== '/' && request.url !== '/design-browser-page.html') {
    response.writeHead(404, { 'content-type': 'text/plain' });
    response.end('not found');
    return;
  }
  const body = await readFile(fixture);
  response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
  response.end(body);
});

server.listen(port, '127.0.0.1', () => {
  const address = server.address();
  process.stdout.write(`listening http://127.0.0.1:${address.port}\n`);
});

process.stdin.on('end', () => server.close());
process.stdin.resume();
