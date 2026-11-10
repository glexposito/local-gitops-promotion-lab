// One real-browser check: what a user opening pulse-api in Chromium sees.
// pulse-api has no UI, so this mostly proves the browser path of the e2e
// image works - it's where a frontend's UI tests would go.
import { test, expect } from '@playwright/test';

test('the home page renders in a browser', async ({ page }) => {
  const res = await page.goto('/');
  expect(res?.status()).toBe(200);
  await expect(page.locator('body')).toHaveText('Hello, World!');
});
