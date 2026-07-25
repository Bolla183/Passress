import { Resend } from "resend";
import { DEFAULT_COMPANY_ID } from "../accounting/company";
import { getExecutiveSummary } from "../accounting/reports";
import { getBusinessHealth } from "../accounting/healthScore";
import { getAIInsights, type Insight } from "../accounting/insights";
import { startOfCairoMonth, endOfCairoMonth } from "../dates";
import { formatEGP } from "../currency";

const SEVERITY_META: Record<Insight["severity"], { emoji: string; label: string }> = {
  critical: { emoji: "\u{1F534}", label: "Critical" },
  warning: { emoji: "\u{1F7E0}", label: "Warning" },
  positive: { emoji: "\u{1F7E2}", label: "Positive" },
  opportunity: { emoji: "\u{1F535}", label: "Opportunity" },
};

const SEVERITY_ORDER: Record<Insight["severity"], number> = {
  critical: 0,
  warning: 1,
  positive: 2,
  opportunity: 3,
};

const TOP_INSIGHT_COUNT = 3;

function row(label: string, value: string, color?: string): string {
  return `<tr>
    <td style="padding:8px 0;color:#767676;font-size:14px;">${label}</td>
    <td style="padding:8px 0;text-align:right;font-size:14px;font-weight:600;${color ? `color:${color};` : ""}">${value}</td>
  </tr>`;
}

function insightBlock(insight: Insight): string {
  const meta = SEVERITY_META[insight.severity];
  return `<div style="margin-bottom:12px;padding:12px 16px;border:1px solid #e6e6e6;border-radius:12px;">
    <p style="margin:0 0 4px;font-size:12px;color:#767676;text-transform:uppercase;letter-spacing:0.05em;">${meta.emoji} ${meta.label}</p>
    <p style="margin:0 0 4px;font-size:14px;font-weight:600;">${insight.title}</p>
    <p style="margin:0;font-size:14px;color:#131313;">${insight.explanation}</p>
  </div>`;
}

export async function buildDailyDigestHtml(companyId = DEFAULT_COMPANY_ID): Promise<{ subject: string; html: string }> {
  const now = new Date();
  const thisMonth = { from: startOfCairoMonth(now), to: endOfCairoMonth(now) };

  const [summary, health, insights] = await Promise.all([
    getExecutiveSummary(thisMonth, companyId),
    getBusinessHealth(companyId),
    getAIInsights(companyId),
  ]);

  const topInsights = [...insights]
    .sort((a, b) => SEVERITY_ORDER[a.severity] - SEVERITY_ORDER[b.severity])
    .slice(0, TOP_INSIGHT_COUNT);

  const dateLabel = now.toLocaleDateString("en-GB", { timeZone: "Africa/Cairo", weekday: "long", day: "numeric", month: "long" });

  const html = `
  <div style="font-family:Helvetica,Arial,sans-serif;color:#131313;max-width:480px;margin:0 auto;padding:24px;">
    <p style="font-size:12px;text-transform:uppercase;letter-spacing:0.1em;color:#767676;margin:0 0 4px;">Passress Daily Digest</p>
    <p style="font-size:13px;color:#767676;margin:0 0 24px;">${dateLabel}</p>

    <div style="border:1px solid #e6e6e6;border-radius:16px;padding:20px;text-align:center;margin-bottom:20px;">
      <p style="font-size:12px;text-transform:uppercase;letter-spacing:0.1em;color:#767676;margin:0 0 6px;">Cash Available</p>
      <p style="font-size:28px;font-weight:700;color:#1f7a4d;margin:0;">${formatEGP(summary.cashBalance)}</p>
    </div>

    <div style="border:1px solid #e6e6e6;border-radius:16px;padding:16px 20px;margin-bottom:20px;">
      <p style="font-size:12px;text-transform:uppercase;letter-spacing:0.1em;color:#767676;margin:0 0 4px;">This Month</p>
      <table style="width:100%;border-collapse:collapse;">
        ${row("Revenue", formatEGP(summary.totalRevenue), "#1f7a4d")}
        ${row("Expenses", formatEGP(summary.totalExpense), "#b3401f")}
        ${row("Profit so far", formatEGP(summary.netProfit), summary.netProfit >= 0 ? "#1f7a4d" : "#b3401f")}
      </table>
    </div>

    <div style="border:1px solid #e6e6e6;border-radius:16px;padding:16px 20px;margin-bottom:20px;">
      <p style="font-size:12px;text-transform:uppercase;letter-spacing:0.1em;color:#767676;margin:0 0 8px;">Business Health</p>
      <p style="margin:0;"><span style="font-size:24px;font-weight:700;color:#9c7a2e;">${health.score}</span><span style="color:#767676;">/100 &middot; ${health.band}</span></p>
      <p style="margin:6px 0 0;font-size:13px;color:#767676;">${health.why.join(" &middot; ")}</p>
    </div>

    ${topInsights.length > 0
      ? `<p style="font-size:12px;text-transform:uppercase;letter-spacing:0.1em;color:#767676;margin:0 0 8px;">Top Insights</p>${topInsights.map(insightBlock).join("")}`
      : ""}

    <p style="font-size:12px;color:#767676;margin-top:24px;">Sent automatically from Passress. Open the app for the full dashboard.</p>
  </div>`;

  return { subject: `Passress Daily Digest -- ${dateLabel}`, html };
}

export async function sendDailyDigest(companyId = DEFAULT_COMPANY_ID) {
  const apiKey = process.env.RESEND_API_KEY;
  const recipients = (process.env.DAILY_DIGEST_RECIPIENTS ?? "")
    .split(",")
    .map((e) => e.trim())
    .filter(Boolean);

  if (!apiKey) throw new Error("RESEND_API_KEY is not configured");
  if (recipients.length === 0) throw new Error("DAILY_DIGEST_RECIPIENTS is not configured");

  const { subject, html } = await buildDailyDigestHtml(companyId);
  const resend = new Resend(apiKey);

  const result = await resend.emails.send({
    from: process.env.DAILY_DIGEST_FROM ?? "Passress <onboarding@resend.dev>",
    to: recipients,
    subject,
    html,
  });

  if (result.error) {
    throw new Error(result.error.message);
  }

  return { sent: recipients.length, id: result.data?.id };
}
