import { test, expect } from "@playwright/test";

const ALLOW_REAL_SUBMISSION = process.env.ALLOW_REAL_FORM_SUBMISSION === "true";

test.describe("Contact form", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/", { waitUntil: "load" });
    const link = page.getByRole("link", { name: /contact/i }).first();
    test.skip(!(await link.count()), 'No "Contact" link found');
    await link.click();
    await page.waitForLoadState("load");
  });

  test("required fields are enforced client-side", async ({ page }) => {
    const form = page.locator('form[action*="/contact"], main form').first();
    await expect(form, "Expected a contact form on the Contact page").toBeVisible();

    const submit = form.getByRole("button", { name: /send|submit/i }).first();
    await submit.click();

    const firstRequired = form.locator("[required]").first();
    if (await firstRequired.count()) {
      const isValid = await firstRequired.evaluate((el: HTMLInputElement | HTMLTextAreaElement) => el.validity.valid);
      expect(isValid, "Expected an empty required field to fail native validation on submit").toBeFalsy();
    } else {
      test.skip(true, "Form has no [required] fields to assert against");
    }
  });

  test("invalid email is rejected", async ({ page }) => {
    const form = page.locator('form[action*="/contact"], main form').first();
    const emailField = form.locator('input[type="email"]').first();
    test.skip(!(await emailField.count()), "No email field on the contact form");

    await emailField.fill("not-an-email");
    const isValid = await emailField.evaluate((el: HTMLInputElement) => el.validity.valid);
    expect(isValid).toBeFalsy();
  });

  test("a fully valid submission is accepted", async ({ page }) => {
    test.skip(
      !ALLOW_REAL_SUBMISSION,
      "Skipped by default to avoid spamming the store's real inbox. Set ALLOW_REAL_FORM_SUBMISSION=true to enable."
    );

    const form = page.locator('form[action*="/contact"], main form').first();
    await form.locator('input[type="email"]').first().fill("qa-test@example.com");
    const nameField = form.locator('input[name*="name" i]').first();
    if (await nameField.count()) await nameField.fill("QA Test");
    const messageField = form.locator("textarea").first();
    if (await messageField.count()) await messageField.fill("Automated QA test submission — please disregard.");

    await form.getByRole("button", { name: /send|submit/i }).first().click();
    await page.waitForLoadState("load");

    const body = await page.locator("body").innerText();
    expect(body.toLowerCase()).toMatch(/thank you|received|we.?ll be in touch|message sent/);
  });
});

test.describe("Track order form", () => {
  test("track-order form validates required inputs", async ({ page }) => {
    await page.goto("/", { waitUntil: "load" });
    const link = page.getByRole("link", { name: /track.*order/i }).first();
    test.skip(!(await link.count()), 'No "Track Order" link found');
    await link.click();
    await page.waitForLoadState("load");

    const form = page.locator("form").first();
    test.skip(!(await form.count()), "No form found on the Track Order page");

    const submit = form.getByRole("button", { name: /track|submit|find/i }).first();
    await submit.click();

    const firstRequired = form.locator("[required]").first();
    if (await firstRequired.count()) {
      const isValid = await firstRequired.evaluate((el: HTMLInputElement) => el.validity.valid);
      expect(isValid).toBeFalsy();
    }
  });

  test("an invalid/unknown order number shows a clear error, not a crash", async ({ page }) => {
    await page.goto("/", { waitUntil: "load" });
    const link = page.getByRole("link", { name: /track.*order/i }).first();
    test.skip(!(await link.count()), 'No "Track Order" link found');
    await link.click();
    await page.waitForLoadState("load");

    const form = page.locator("form").first();
    test.skip(!(await form.count()), "No form found on the Track Order page");

    const orderField = form.locator('input[name*="order" i], input[type="text"]').first();
    const emailField = form.locator('input[type="email"]').first();

    if (await orderField.count()) await orderField.fill("#00000-NOTREAL");
    if (await emailField.count()) await emailField.fill("qa-test@example.com");

    await form.getByRole("button", { name: /track|submit|find/i }).first().click();
    await page.waitForLoadState("load").catch(() => {});

    const body = await page.locator("body").innerText();
    expect(body.toLowerCase()).toMatch(/not found|couldn.?t find|no order|invalid|check.*details/);
  });
});
