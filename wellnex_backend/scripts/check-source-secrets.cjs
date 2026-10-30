// Minimal regression barrier; complement with repository-wide secret scanning.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const repo = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(repo, 'wellnex_backend/test-smtp.js'), 'utf8');
const failures = [];
if (/\bpass\s*:\s*["']/.test(source)) failures.push('SMTP diagnostic contains a literal password');
const files = cp.execFileSync('git', ['ls-files', '-z'], { cwd: repo, encoding: 'utf8' }).split('\0').filter(Boolean);
for (const name of files) {
  if (/\.(?:jks|keystore)$|(?:^|\/)key\.properties$/.test(name)) failures.push(`Signing material is tracked: ${name}`);
}
if (failures.length) { console.error(failures.join('\n')); process.exitCode = 1; }
else console.log('Source credential regression checks passed.');
