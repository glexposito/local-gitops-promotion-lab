// pulse-api's e2e tests, run against an already-deployed pulse-api - nothing
// is started here. BASE_URL picks the target:
//   BASE_URL=http://localhost:8081 npx playwright test       (internal)
// In Kargo, run.sh sets it from the URL the verification passes in.
import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.BASE_URL;
if (!baseURL) throw new Error('Set BASE_URL, e.g. BASE_URL=http://localhost:8081');

export default defineConfig({
  testDir: './tests',
  // Fail the run if someone leaves a test.only behind.
  forbidOnly: !!process.env.CI,
  // A verification is a yes/no gate: retries would hide flakiness, and
  // pulse-api is small enough that tests don't need to run in parallel.
  retries: 0,
  workers: 1,
  // Logs are the only output Kargo keeps (no artifact storage), so print
  // every test as it runs.
  reporter: [['list']],
  use: {
    baseURL,
    trace: 'off',
  },
  projects: [
    { name: 'api', testMatch: /api\.spec\.ts/ },
    { name: 'chromium', testMatch: /browser\.spec\.ts/, use: { ...devices['Desktop Chrome'] } },
  ],
});
