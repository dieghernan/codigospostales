// Serve the built site at its project base path, without extra dependencies.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../../docs/_site');
const base = process.env.SITE_BASEURL ?? '/codigospostales';
const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.geojson': 'application/geo+json', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.woff2': 'font/woff2' };
http.createServer((req, res) => {
  const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  if (!pathname.startsWith(base + '/')) { res.writeHead(404).end(); return; }
  let file = path.resolve(root, '.' + pathname.slice(base.length));
  if (!file.startsWith(root + path.sep) && file !== root) { res.writeHead(403).end(); return; }
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  fs.readFile(file, (error, content) => {
    if (error) { res.writeHead(404).end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    // Chulapa emits absolute asset URLs; relocate only this project's URLs
    // when previewing, so checks exercise the built CSS/JS rather than production.
    res.end(path.extname(file) === '.html'
      ? content.toString().replaceAll(`https://dieghernan.github.io${base}/`, `${base}/`)
      : content);
  });
}).listen(4173, '127.0.0.1');
