// Renders the built /resume page to dist/resume.pdf using the system Chromium
// installed in the build stage (set CHROMIUM_PATH if it's not auto-detected).
import { createServer } from 'node:http';
import { createReadStream, existsSync, statSync } from 'node:fs';
import { extname, join } from 'node:path';
import puppeteer from 'puppeteer-core';

const DIST = new URL('../dist/', import.meta.url).pathname;
const MIME = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.jpg': 'image/jpeg', '.ico': 'image/x-icon', '.svg': 'image/svg+xml' };

const server = createServer((req, res) => {
  let path = join(DIST, req.url.split('?')[0]);
  if (existsSync(path) && statSync(path).isDirectory()) path = join(path, 'index.html');
  if (!existsSync(path)) {
    res.writeHead(404);
    res.end();
    return;
  }
  res.writeHead(200, { 'Content-Type': MIME[extname(path)] ?? 'application/octet-stream' });
  createReadStream(path).pipe(res);
});

await new Promise((resolve) => server.listen(0, resolve));
const { port } = server.address();

const executablePath = process.env.CHROMIUM_PATH || '/usr/bin/chromium-browser';
const browser = await puppeteer.launch({
  executablePath,
  args: ['--no-sandbox', '--disable-setuid-sandbox'],
});
const page = await browser.newPage();
await page.goto(`http://127.0.0.1:${port}/resume/`, { waitUntil: 'networkidle0' });
await page.pdf({
  path: join(DIST, 'resume.pdf'),
  format: 'a4',
  printBackground: true,
  margin: { top: '20mm', bottom: '20mm', left: '18mm', right: '18mm' },
});
await browser.close();
server.close();

console.log('Wrote dist/resume.pdf');
