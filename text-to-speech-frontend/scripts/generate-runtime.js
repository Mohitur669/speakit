const fs = require('fs');
const path = require('path');

const apiUrl = process.env.API_URL || 'http://localhost:8080';
const content = `window.__env = { API_URL: '${apiUrl}' };`;

const outDir = path.join(__dirname, '..', 'public');
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'runtime-env.js'), content, 'utf8');
console.log('Wrote runtime-env.js with API_URL=' + apiUrl);
