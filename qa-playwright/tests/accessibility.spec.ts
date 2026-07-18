import { test, expect } from "@playwright/test";
import { runAxeScan, summarizeViolations } from "./utils/a11y";
import { goToCollection, openFirstProduct } from "./utils/shop-flows";

test.describe("Accessibility (axe-core)", () => {
  test("homepage has no critical/serious a11y violations", async ({ page }, testInfo) => {
    await page.goto("/", { waitUntil: "load" });
    const { critical, serious, moderate } = await runAxeScan(page, testInfo, "homepage");

    if (moderate.length) {
      testInfo.annotations.push({ type: "a11y-moderate", description: summarizeViolations(moderate) });
    }
    expect(critical.length + serious.length, summarizeViolations([...critical, ...serious])).toBe(0);
  });

  test("collection page has no critical/serious a11y violations", async ({ page }, testInfo) => {
    await goToCollection(page, testInfo.project.use.baseURL as string);
    const { critical, serious } = await runAxeScan(page, testInfo, "collection");
    expect(critical.length + serious.length, summarizeViolations([...critical, ...serious])).toBe(0);
  });

  test("product page has no critical/serious a11y violations", async ({ page }, testInfo) => {
    await goToCollection(page, testInfo.project.use.baseURL as string);
    await openFirstProduct(page);
    const { critical, serious } = await runAxeScan(page, testInfo, "product");
    expect(critical.length + serious.length, summarizeViolations([...critical, ...serious])).toBe(0);
  });

  test("cart page has no critical/serious a11y violations", async ({ page }) => {
    await page.goto("/cart", { waitUntil: "load" });
    const { critical, serious } = await runAxeScan(page, test.info(), "cart");
    expect(critical.length + serious.length, summarizeViolations([...critical, ...serious])).toBe(0);
  });

  test("all images across the homepage have accessible alt text (informational)", async ({ page }, testInfo) => {
    await page.goto("/", { waitUntil: "networkidle" });
    const { all } = await runAxeScan(page, testInfo, "homepage-images");
    const imageAltViolations = all.filter((v) => v.id === "image-alt");
    expect(imageAltViolations.length, summarizeViolations(imageAltViolations)).toBe(0);
  });
});
