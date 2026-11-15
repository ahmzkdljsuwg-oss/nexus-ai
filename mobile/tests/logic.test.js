import test from 'node:test';
import assert from 'node:assert/strict';
import { normaliseBaseUrl, friendlyError } from '../src/api/client.js';
import { t, directionLabel, resultLabel } from '../src/i18n.js';

test('normaliseBaseUrl accepts only real http(s) URLs', () => {
  assert.equal(normaliseBaseUrl('https://svc.up.railway.app/'), 'https://svc.up.railway.app');
  assert.equal(normaliseBaseUrl('http://localhost:8000'), 'http://localhost:8000');
  assert.equal(normaliseBaseUrl('svc.up.railway.app'), '');
  assert.equal(normaliseBaseUrl(''), '');
  assert.equal(normaliseBaseUrl(null), '');
});

test('friendlyError surfaces server detail without leaking config', () => {
  assert.match(friendlyError({ response: { status: 503, data: { detail: { message: 'DATA_UNAVAILABLE' } } } }), /DATA_UNAVAILABLE/);
  assert.match(friendlyError({ code: 'ECONNABORTED' }), /did not answer/);
  assert.match(friendlyError({ response: { status: 404 } }), /route not found/);
  assert.match(friendlyError({}), /Cannot reach/);
});

test('localization switches Arabic and English without mixing', () => {
  assert.equal(t('en', 'Home', 'الرئيسية'), 'Home');
  assert.equal(t('ar', 'Home', 'الرئيسية'), 'الرئيسية');
  assert.equal(directionLabel('ar', 'UP'), 'شراء / UP');
  assert.equal(directionLabel('en', 'DOWN'), 'SELL / DOWN');
  assert.equal(resultLabel('ar', 'WIN'), 'رابحة');
  assert.equal(resultLabel('en', 'UNVERIFIED'), 'UNVERIFIED');
});
