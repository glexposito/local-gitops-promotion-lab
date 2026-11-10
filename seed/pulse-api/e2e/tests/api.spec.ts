// pulse-api's API checks, as Playwright API tests - no browser needed.
import { test, expect } from '@playwright/test';

// A freshly synced deployment may still be rolling out.
test.beforeAll(async ({ request }) => {
  await expect
    .poll(async () => (await request.get('/ready')).status(), { timeout: 60_000, intervals: [2_000] })
    .toBe(200);
});

test('GET /live is 200', async ({ request }) => {
  expect((await request.get('/live')).status()).toBe(200);
});

test('GET /ready is 200', async ({ request }) => {
  expect((await request.get('/ready')).status()).toBe(200);
});

for (const path of ['/', '/hello']) {
  test(`GET ${path} says hello`, async ({ request }) => {
    const res = await request.get(path);
    expect(res.status()).toBe(200);
    expect(await res.text()).toBe('Hello, World!');
  });
}

test('unknown path is 404', async ({ request }) => {
  expect((await request.get('/does-not-exist')).status()).toBe(404);
});

// /hostname returns the serving pod's name. Hit it a few times to check
// it's really answered by pulse-api pods behind the Service, and log how
// requests spread across replicas.
test('GET /hostname is served by pulse-api pods', async ({ request }) => {
  const counts = new Map<string, number>();
  for (let i = 0; i < 20; i++) {
    const res = await request.get('/hostname');
    expect(res.status()).toBe(200);
    const pod = (await res.text()).trim();
    counts.set(pod, (counts.get(pod) ?? 0) + 1);
  }
  console.log(Object.fromEntries(counts));
  for (const pod of counts.keys()) expect(pod).toMatch(/^pulse-api-/);
});
