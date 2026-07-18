import { defineConfig, devices } from "@playwright/test";
import * as dotenv from "dotenv";
import path from "path";

dotenv.config({ path: path.resolve(__dirname, ".env") });

export const BASE_URL = (process.env.BASE_URL || "https://www.passress.com").replace(/\/+$/, "");
export const PREVIEW_THEME_ID = process.env.PREVIEW_THEME_ID || "";
export const STOREFRONT_PASSWORD = process.env.STOREFRONT_PASSWORD || "";
export const STORAGE_STATE = path.resolve(__dirname, ".auth/storefront-state.json");

export default defineConfig({
  testDir: "./tests",
  fullyParallel: false,
  workers: 1,
  forbidOnly: !!process.env.CI,
  retries: 1,
  reporter: [["html", { open: "never" }], ["list"]],
  timeout: 45_000,
  expect: { timeout: 10_000 },
  globalSetup: require.resolve("./tests/global-setup"),
  use: {
    baseURL: BASE_URL,
    storageState: STORAGE_STATE,
    screenshot: "only-on-failure",
    video: "retain-on-failure",
    trace: "retain-on-failure",
    ignoreHTTPSErrors: false,
    // Only set when you've pinned a specific browser build instead of
    // letting `npx playwright install` manage it (see README).
    launchOptions: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE
      ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE }
      : undefined,
  },
  projects: [
    {
      name: "Desktop",
      use: {
        ...devices["Desktop Chrome"],
        viewport: { width: 1440, height: 900 },
        browserName: "chromium",
      },
    },
    {
      name: "Tablet",
      // Emulated via Chromium (not WebKit) so the pre-installed browser
      // binary in this environment can run it; still exercises the real
      // tablet viewport/touch/UA behavior that matters for responsive QA.
      use: { ...devices["iPad (gen 7)"], defaultBrowserType: undefined, browserName: "chromium" },
    },
    {
      name: "Mobile",
      use: { ...devices["iPhone 13"], defaultBrowserType: undefined, browserName: "chromium" },
    },
  ],
});
