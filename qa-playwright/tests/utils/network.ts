import { Page, APIRequestContext, TestInfo } from "@playwright/test";

export interface PageIssueTracker {
  consoleErrors: string[];
  pageErrors: string[];
  failedRequests: string[];
  badResponses: string[];
}

/** Attaches listeners that record console errors, JS exceptions, failed
 * requests and 4xx/5xx responses for the lifetime of the page. Call this
 * once per test, right after the page is created/navigated. */
export function trackPageIssues(page: Page): PageIssueTracker {
  const tracker: PageIssueTracker = {
    consoleErrors: [],
    pageErrors: [],
    failedRequests: [],
    badResponses: [],
  };

  page.on("console", (msg) => {
    if (msg.type() === "error") {
      tracker.consoleErrors.push(msg.text());
    }
  });

  page.on("pageerror", (err) => {
    tracker.pageErrors.push(err.message);
  });

  page.on("requestfailed", (req) => {
    // Ignore aborted requests caused by client-side navigation/redirects,
    // which are noisy false positives rather than real failures.
    const failure = req.failure()?.errorText || "";
    if (failure.includes("net::ERR_ABORTED")) return;
    tracker.failedRequests.push(`${req.method()} ${req.url()} — ${failure}`);
  });

  page.on("response", (res) => {
    const status = res.status();
    if (status >= 400) {
      tracker.badResponses.push(`${status} ${res.request().method()} ${res.url()}`);
    }
  });

  return tracker;
}

/** Formats a tracker into a human-readable block for test failure messages,
 * or an empty string if nothing was recorded. */
export function formatIssues(tracker: PageIssueTracker): string {
  const sections: string[] = [];
  if (tracker.consoleErrors.length) {
    sections.push(`Console errors:\n  - ${tracker.consoleErrors.join("\n  - ")}`);
  }
  if (tracker.pageErrors.length) {
    sections.push(`Uncaught JS exceptions:\n  - ${tracker.pageErrors.join("\n  - ")}`);
  }
  if (tracker.failedRequests.length) {
    sections.push(`Failed requests:\n  - ${tracker.failedRequests.join("\n  - ")}`);
  }
  if (tracker.badResponses.length) {
    sections.push(`HTTP error responses:\n  - ${tracker.badResponses.join("\n  - ")}`);
  }
  return sections.join("\n\n");
}

/** Collects every <img> on the current page and reports ones that fail to
 * decode (broken image) or are missing alt text (accessibility). */
export async function auditImages(page: Page) {
  return page.evaluate(() => {
    const imgs = Array.from(document.querySelectorAll("img"));
    return imgs.map((img) => ({
      src: img.currentSrc || img.src,
      alt: img.getAttribute("alt"),
      broken: img.complete && img.naturalWidth === 0,
      loading: img.getAttribute("loading"),
    }));
  });
}

/** Collects every same-origin and external hyperlink on the page. */
export async function collectLinks(page: Page): Promise<string[]> {
  const hrefs = await page.evaluate(() =>
    Array.from(document.querySelectorAll("a[href]"))
      .map((a) => (a as HTMLAnchorElement).href)
      .filter(Boolean)
  );
  return Array.from(new Set(hrefs)).filter(
    (href) => !href.startsWith("mailto:") && !href.startsWith("tel:") && !href.startsWith("javascript:")
  );
}

export interface LinkCheckResult {
  url: string;
  status: number | null;
  ok: boolean;
  error?: string;
}

/** Validates a batch of links with lightweight HEAD (falling back to GET)
 * requests via Playwright's APIRequestContext — much faster than opening a
 * page per link. Returns only the broken ones. */
export async function findBrokenLinks(
  request: APIRequestContext,
  urls: string[],
  concurrency = 6
): Promise<LinkCheckResult[]> {
  const results: LinkCheckResult[] = [];
  let index = 0;

  async function worker() {
    while (index < urls.length) {
      const url = urls[index++];
      try {
        let res = await request.head(url, { maxRedirects: 5, timeout: 15_000 });
        // Some servers (or CDNs) don't support HEAD — retry with GET.
        if (res.status() === 405 || res.status() === 501) {
          res = await request.get(url, { maxRedirects: 5, timeout: 15_000 });
        }
        if (res.status() >= 400) {
          results.push({ url, status: res.status(), ok: false });
        }
      } catch (err: any) {
        results.push({ url, status: null, ok: false, error: err?.message || String(err) });
      }
    }
  }

  await Promise.all(Array.from({ length: Math.min(concurrency, urls.length) }, worker));
  return results;
}

/** Attaches a full-page screenshot to the test report — call from a
 * try/catch or a custom afterEach when an assertion is about to fail. */
export async function attachFailureScreenshot(page: Page, testInfo: TestInfo, name: string) {
  const screenshot = await page.screenshot({ fullPage: true });
  await testInfo.attach(name, { body: screenshot, contentType: "image/png" });
}
