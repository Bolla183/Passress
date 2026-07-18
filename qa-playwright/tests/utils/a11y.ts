import { Page, TestInfo } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import type { Result } from "axe-core";

/** Runs an axe-core scan against the current page state and attaches the
 * full JSON report to the test result. Returns violations grouped by
 * impact so callers can decide what severity to fail on. */
export async function runAxeScan(page: Page, testInfo: TestInfo, label: string) {
  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "best-practice"])
    .analyze();

  await testInfo.attach(`axe-${label}.json`, {
    body: JSON.stringify(results.violations, null, 2),
    contentType: "application/json",
  });

  const critical = results.violations.filter((v) => v.impact === "critical");
  const serious = results.violations.filter((v) => v.impact === "serious");
  const moderate = results.violations.filter((v) => v.impact === "moderate");
  const minor = results.violations.filter((v) => v.impact === "minor");

  return { all: results.violations, critical, serious, moderate, minor };
}

export function summarizeViolations(violations: Result[]) {
  return violations
    .map((v) => `[${v.impact}] ${v.id}: ${v.help} (${v.nodes.length} node(s)) — ${v.helpUrl}`)
    .join("\n");
}
