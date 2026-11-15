import test from 'node:test';
import assert from 'node:assert/strict';
import { pickBaseUrl, splashCanFinish, splashStatus } from '../src/state/startup.js';

test('production build URL wins over a stale saved fallback', () => {
  assert.equal(
    pickBaseUrl({ buildUrl: 'https://nexus-production.up.railway.app/', savedUrl: 'http://localhost:8000' }),
    'https://nexus-production.up.railway.app',
  );
  assert.equal(pickBaseUrl({ buildUrl: '', savedUrl: 'https://fallback.example.com/' }), 'https://fallback.example.com');
  assert.equal(pickBaseUrl({ buildUrl: 'not-a-url', savedUrl: '' }), '');
});

test('splash waits for boot and minimum time, then always times out', () => {
  assert.equal(splashCanFinish({ elapsed: false, ready: true, booting: false, forced: false }), false);
  assert.equal(splashCanFinish({ elapsed: true, ready: true, booting: true, forced: false }), false);
  assert.equal(splashCanFinish({ elapsed: true, ready: true, booting: false, forced: false }), true);
  assert.equal(splashCanFinish({ elapsed: true, ready: false, booting: true, forced: true }), true);
});

test('splash status never claims a connection without a URL', () => {
  assert.match(splashStatus({ baseUrl: '', booting: true, language: 'en' }), /AWAITING SERVER/);
  assert.match(splashStatus({ baseUrl: 'https://svc.up.railway.app', booting: false, connection: { state: 'online' }, language: 'en' }), /VERIFIED/);
  assert.match(splashStatus({ baseUrl: 'https://svc.up.railway.app', booting: false, connection: { state: 'offline' }, language: 'ar' }), /غير متاح/);
});
