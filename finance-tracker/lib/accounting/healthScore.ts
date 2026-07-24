import { DEFAULT_COMPANY_ID } from "./company";
import { getExecutiveSummary, getBalanceSheet, getAccountBalance } from "./reports";
import { getAccountByCode } from "./ledger";
import { addMonths, startOfCairoMonth, endOfCairoMonth } from "../dates";

// Linear interpolation between two reference points, clamped to [0, 100] on
// both ends -- the shared shape behind every factor below, so a "0% growth
// scores 50, +20% scores 100" rule reads the same way in every factor.
function scoreBetween(value: number, x0: number, y0: number, x1: number, y1: number): number {
  if (value <= x0) return y0;
  if (value >= x1) return y1;
  return y0 + ((value - x0) / (x1 - x0)) * (y1 - y0);
}

function growthCurve(growth: number): number {
  if (growth <= -0.2) return 0;
  if (growth <= 0) return scoreBetween(growth, -0.2, 0, 0, 50);
  if (growth <= 0.2) return scoreBetween(growth, 0, 50, 0.2, 100);
  return 100;
}

export type HealthFactor = { name: string; score: number; weight: number; detail: string };

export type BusinessHealth = {
  score: number;
  band: "Excellent" | "Good" | "Fair" | "Needs Attention" | "At Risk";
  factors: HealthFactor[];
  why: string[];
};

function bandFor(score: number): BusinessHealth["band"] {
  if (score >= 85) return "Excellent";
  if (score >= 70) return "Good";
  if (score >= 50) return "Fair";
  if (score >= 30) return "Needs Attention";
  return "At Risk";
}

// Five factors, weighted, each already derivable from the existing reports
// engine -- never a guess. See PRD §06 for the reference points each curve
// is built from.
export async function getBusinessHealth(companyId = DEFAULT_COMPANY_ID): Promise<BusinessHealth> {
  const now = new Date();
  const thisMonth = { from: startOfCairoMonth(now), to: endOfCairoMonth(now) };
  const lastMonthDate = addMonths(now, -1);
  const lastMonth = { from: startOfCairoMonth(lastMonthDate), to: endOfCairoMonth(lastMonthDate) };
  const twoMonthsAgoDate = addMonths(now, -2);
  const twoMonthsAgo = { from: startOfCairoMonth(twoMonthsAgoDate), to: endOfCairoMonth(twoMonthsAgoDate) };

  const [current, previous, twoAgo, balanceSheet, rawInventory, finishedInventory] = await Promise.all([
    getExecutiveSummary(thisMonth, companyId),
    getExecutiveSummary(lastMonth, companyId),
    getExecutiveSummary(twoMonthsAgo, companyId),
    getBalanceSheet(now, companyId),
    getAccountByCode("1200", companyId).then((a) => getAccountBalance(a.id, now, companyId)),
    getAccountByCode("1210", companyId).then((a) => getAccountBalance(a.id, now, companyId)),
  ]);

  const avgMonthlyExpense = (current.totalExpense + previous.totalExpense + twoAgo.totalExpense) / 3 || 0;
  const runwayMonths = avgMonthlyExpense > 0 ? current.cashBalance / avgMonthlyExpense : current.cashBalance > 0 ? 6 : 0;
  const cashScore = scoreBetween(runwayMonths, 0, 0, 3, 100);

  const margin = current.totalRevenue > 0 ? current.netProfit / current.totalRevenue : current.netProfit >= 0 ? 0 : -1;
  const profitScore =
    margin <= -0.2 ? 0 : margin <= 0 ? scoreBetween(margin, -0.2, 0, 0, 50) : scoreBetween(margin, 0, 50, 0.25, 100);

  const revenueGrowth = previous.totalRevenue > 0 ? (current.totalRevenue - previous.totalRevenue) / previous.totalRevenue : 0;
  const revenueGrowthScore = growthCurve(revenueGrowth);

  const expenseGrowth = previous.totalExpense > 0 ? (current.totalExpense - previous.totalExpense) / previous.totalExpense : 0;
  const controlDelta = revenueGrowth - expenseGrowth;
  const controlScore = growthCurve(controlDelta);

  const inventoryValue = rawInventory + finishedInventory;
  const liquidityRatio =
    balanceSheet.totalLiabilities > 0 ? (current.cashBalance + inventoryValue) / balanceSheet.totalLiabilities : 2;
  const liquidityScore = scoreBetween(liquidityRatio, 0.5, 0, 2, 100);

  const factors: HealthFactor[] = [
    { name: "Cash Position", score: cashScore, weight: 0.25, detail: `${runwayMonths.toFixed(1)} months of runway` },
    { name: "Profitability", score: profitScore, weight: 0.25, detail: `${(margin * 100).toFixed(0)}% net margin` },
    { name: "Revenue Growth", score: revenueGrowthScore, weight: 0.2, detail: `${(revenueGrowth * 100).toFixed(0)}% vs last month` },
    { name: "Expense Control", score: controlScore, weight: 0.15, detail: `${(expenseGrowth * 100).toFixed(0)}% expense growth` },
    { name: "Liquidity", score: liquidityScore, weight: 0.15, detail: `${liquidityRatio.toFixed(1)}x cash+inventory to liabilities` },
  ];

  const score = Math.round(factors.reduce((sum, f) => sum + f.score * f.weight, 0));
  const sorted = [...factors].sort((a, b) => b.score - a.score);
  const best = sorted[0];
  const worst = sorted[sorted.length - 1];

  const why: string[] = [];
  why.push(sentenceFor(best, toneFor(best.score)));
  if (worst.name !== best.name) why.push(sentenceFor(worst, toneFor(worst.score)));

  return { score, band: bandFor(score), factors, why };
}

export type FactorTone = "positive" | "neutral" | "negative";

// 50 is the deliberate neutral midpoint every factor's scoring curve is
// built around (e.g. 0% revenue growth scores exactly 50) -- treating it
// as "positive" would read as a contradiction ("Revenue is growing — 0%").
export function toneFor(score: number): FactorTone {
  if (score > 50) return "positive";
  if (score < 50) return "negative";
  return "neutral";
}

export function sentenceFor(factor: HealthFactor, tone: FactorTone): string {
  switch (factor.name) {
    case "Cash Position":
      if (tone === "positive") return `Strong cash position — ${factor.detail}`;
      if (tone === "negative") return `Cash position needs attention — ${factor.detail}`;
      return `Cash position is adequate — ${factor.detail}`;
    case "Profitability":
      if (tone === "positive") return `Healthy margin — ${factor.detail}`;
      if (tone === "negative") return `Margin is thin — ${factor.detail}`;
      return `Break-even margin — ${factor.detail}`;
    case "Revenue Growth":
      if (tone === "positive") return `Revenue is growing — ${factor.detail}`;
      if (tone === "negative") return `Revenue has slowed — ${factor.detail}`;
      return `Revenue is flat — ${factor.detail}`;
    case "Expense Control":
      if (tone === "positive") return "Expenses are under control relative to revenue";
      if (tone === "negative") return "Expenses are growing faster than revenue";
      return "Expenses are growing in line with revenue";
    case "Liquidity":
      if (tone === "positive") return "Solid liquidity to cover short-term obligations";
      if (tone === "negative") return "Liquidity is tight relative to what's owed";
      return "Liquidity roughly covers what's owed";
    default:
      return "";
  }
}
