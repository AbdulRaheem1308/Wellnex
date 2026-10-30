const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');
function invoke(configured, provided) {
  const source = fs.readFileSync(path.join(__dirname, '../src/middleware/auth.ts'), 'utf8');
  const output = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText;
  const exports = {};
  vm.runInNewContext(output, { exports, require, Buffer, process: { env: { ADMIN_API_KEY: configured } } });
  let status = 200, allowed = false;
  exports.adminAuthGuard({ headers: { 'x-admin-api-key': provided } }, { status(code) { status = code; return this; }, json() {} }, () => { allowed = true; });
  return { status, allowed };
}
test('missing/default configuration always denies access', () => {
  for (const configured of [undefined, '', 'fallback-secret-admin-key-2026']) {
    assert.deepEqual(invoke(configured, 'fallback-secret-admin-key-2026'), { status: 503, allowed: false });
  }
});
test('only exact configured string credentials allow access', () => {
  for (const value of [undefined, 'wrong', ['test-key'], '']) assert.deepEqual(invoke('test-key', value), { status: 401, allowed: false });
  assert.deepEqual(invoke('test-key', 'test-key'), { status: 200, allowed: true });
});
