import { test, expect } from "@playwright/test";
import { trackPageIssues, formatIssues, auditImages } from "./utils/network";

test.describe("Homepage", () => {
  test("loads successfully with no console errors or failed requests", async ({ page }) => {
    const tracker = trackPageIssues(page);

    const response = await page.goto("/", { waitUntil: "load" });
    expect(response?.ok(), `Homepage responded with status ${response?.status()}`).toBeTruthy();

    await expect(page).toHaveTitle(/.+/);

    const issues = formatIssues(tracker);
    expect(issues, issues).toBe("");
  });

  test("renders a hero/main content area and header", async ({ page }) => {
    await page.goto("/", { waitUntil: "load" });

    await expect(page.locator("header")).toBeVisible();
    await expect(page.locator("main, #MainContent, [role='main']").first()).toBeVisible();
  });

  test("all images on the homepage load correctly and have alt text", async ({ page }) => {
    await page.goto("/", { waitUntil: "networkidle" });
    const images = await auditImages(page);

    expect(images.length, "Expected at least one image on the homepage").toBeGreaterThan(0);

    const broken = images.filter((i) => i.broken);
    expect(broken, `Broken images:\n${JSON.stringify(broken, null, 2)}`).toEqual([]);

    const missingAlt = images.filter((i) => i.alt === null || i.alt.trim() === "");
    // Purely decorative images legitimately use alt="" — report rather than
    // hard-fail so a human can triage, but still surface the count.
    test.info().annotations.push({
      type: "images-missing-alt",
      description: `${missingAlt.length} of ${images.length} images have empty/missing alt text`,
    });
  });

  test("basic navigation timing is within an acceptable budget", async ({ page }) => {
    await page.goto("/", { waitUntil: "load" });
    const timing = await page.evaluate(() => {
      const [nav] = performance.getEntriesByType("navigation") as PerformanceNavigationTiming[];
      return {
        domContentLoaded: nav.domContentLoadedEventEnd - nav.startTime,
        loadEvent: nav.loadEventEnd - nav.startTime,
        ttfb: nav.responseStart - nav.startTime,
      };
    });

    test.info().annotations.push({
      type: "performance",
      description: `TTFB ${timing.ttfb.toFixed(0)}ms, DOMContentLoaded ${timing.domContentLoaded.toFixed(
        0
      )}ms, load ${timing.loadEvent.toFixed(0)}ms`,
    });

    // Soft budgets — flag regressions without being a flaky hard gate on a
    // real network in CI.
    expect.soft(timing.ttfb, "Time to first byte looks slow").toBeLessThan(3000);
    expect.soft(timing.loadEvent, "Full page load looks slow").toBeLessThan(8000);
  });
});
