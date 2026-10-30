const { test } = require('node:test');
const assert = require('node:assert/strict');
const { verifySmtp } = require('../test-smtp');
test('missing credentials cannot create a transport', async () => {
  for (const env of [{}, { SMTP_USER: 'audit@example.invalid' }, { SMTP_PASS: 'test-only' }]) {
    await assert.rejects(verifySmtp(env, () => { assert.fail('Transport must not load'); }), /Set SMTP_USER/);
  }
});
test('configured diagnostic requires TLS and only verifies', async () => {
  let closed = false;
  await verifySmtp({ SMTP_USER: 'audit@example.invalid', SMTP_PASS: 'test-only' }, () => ({
    createTransport: options => {
      assert.equal(options.requireTLS, true);
      assert.deepEqual(options.auth, { user: 'audit@example.invalid', pass: 'test-only' });
      return { verify: async () => {}, close: () => { closed = true; } };
    },
  }));
  assert.equal(closed, true);
});
test('failed verification still closes transport', async () => {
  let closed = false;
  await assert.rejects(verifySmtp({ SMTP_USER: 'audit@example.invalid', SMTP_PASS: 'test-only' }, () => ({
    createTransport: () => ({ verify: async () => { throw new Error('Mock failure'); }, close: () => { closed = true; } }),
  })), /Mock failure/);
  assert.equal(closed, true);
});
