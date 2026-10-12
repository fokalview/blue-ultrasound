import {test} from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';

const env = {ASSETS: {fetch: async () => new Response('app shell')} as unknown as Fetcher};
test('health identifies local-only release', async () => {
  const response = await worker.fetch(new Request('https://blue.test/api/health'), env);
  assert.equal(response.status, 200);
  assert.equal((await response.json() as {storage: string}).storage, 'disabled');
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
});
test('no study write accepts data, even with a bearer token', async () => {
  for (const method of ['POST', 'PUT', 'PATCH', 'DELETE']) {
    const response = await worker.fetch(new Request('https://blue.test/api/v1/studies', {method, headers: {Authorization: 'Bearer fake'}, body: '{}'}), env);
    assert.equal(response.status, 503);
  }
});
test('hardware adapters cannot be mistaken for available connections', async () => {
  const response = await worker.fetch(new Request('https://blue.test/api/v1/device-capabilities'), env);
  const body = await response.json() as {adapters: {source: string; available: boolean}[]};
  assert.ok(body.adapters.filter(a => a.source === 'hardware').every(a => !a.available));
});
test('unknown API routes never serve an app shell', async () => {
  assert.equal((await worker.fetch(new Request('https://blue.test/api/v1/studies'), env)).status, 404);
});
test('non-API navigation serves static application', async () => {
  assert.equal(await (await worker.fetch(new Request('https://blue.test/studies'), env)).text(), 'app shell');
});
