import { DEFAULT_COMPANY_ID } from "./company";
import {
  getExecutiveSummary,
  getBalanceSheet,
  getProfitAndLoss,
  type ExecutiveSummary,
  type AccountRollupRow,
} from "./reports";
import { getCapitalInvested } from "../modules/capital";
import { CHART_OF_ACCOUNTS, type AccountSeedNode } from "./chartOfAccountsSeed";
import { addMonths, startOfCairoMonth, endOfCairoMonth } from "../dates";
import { formatEGP } from "../currency";

// Plain-language analysis of the business -- distinct from the Business
// Health Score's weighted 0-100 formula. Every insight here is a
// deterministic rule over real ledger data (never invented, never a live
// model call), so the feed is reproducible and free to compute on every
// Dashboard load -- it simply reflects whatever the ledger currently says.
// Copy is deliberately plain and conversational, not accounting jargon.

export type InsightSeverity = "critical" | "warning" | "positive" | "opportunity";
export type Confidence = "High" | "Medium" | "Low";

export type Insight = {
  id: string;
  title: string;
  severity: InsightSeverity;
  explanation: string;
  whyItMatters: string;
  action: string;
  confidence: Confidence;
};

const SEVERITY_ORDER: Record<InsightSeverity, number> = {
  critical: 0,
  warning: 1,
  positive: 2,
  opportunity: 3,
};

// Account codes that have children in the seed tree are rollup parents
// ("COGS / Inventory") -- everything else is a true leaf category
// ("Fabric", "Meta Ads"). Computed once from the static seed so category
// insights can name the specific cost driver instead of the coarse
// top-level bucket.
function collectParentCodes(nodes: AccountSeedNode[], set: Set<string>) {
  for (const node of nodes) {
    if (node.children && node.children.length > 0) {
      set.add(node.code);
      collectParentCodes(node.children, set);
    }
  }
}
const PARENT_CODES = (() => {
  const set = new Set<string>();
  collectParentCodes(CHART_OF_ACCOUNTS, set);
  return set;
})();

function leafRows(rows: AccountRollupRow[]): AccountRollupRow[] {
  return rows.filter((r) => !PARENT_CODES.has(r.code) && !r.code.endsWith("-GROUP"));
}

function pct(part: number, whole: number): number {
  return whole > 0 ? Math.round((part / whole) * 100) : 0;
}

// "3½" instead of "3.5" -- casual, not a decimal.
function formatMonths(months: number): string {
  const rounded = Math.round(months * 2) / 2;
  return Number.isInteger(rounded) ? String(rounded) : `${Math.floor(rounded)}½`;
}

const MATERIAL_LEAF_NAMES = new Set(["Fabric", "Production", "Sample Production"]);

type Bundle = {
  current: ExecutiveSummary;
  previous: ExecutiveSummary;
  twoAgo: ExecutiveSummary;
  allTimeRevenue: number;
  allTimeExpense: number;
  capitalInvested: number;
  balanceSheet: Awaited<ReturnType<typeof getBalanceSheet>>;
  currentLeaves: AccountRollupRow[];
};

async function buildBundle(companyId: string): Promise<Bundle> {
  const now = new Date();
  const thisMonth = { from: startOfCairoMonth(now), to: endOfCairoMonth(now) };
  const lastMonthDate = addMonths(now, -1);
  const lastMonth = { from: startOfCairoMonth(lastMonthDate), to: endOfCairoMonth(lastMonthDate) };
  const twoAgoDate = addMonths(now, -2);
  const twoAgoRange = { from: startOfCairoMonth(twoAgoDate), to: endOfCairoMonth(twoAgoDate) };
  const allTimeFrom = new Date("2000-01-01T00:00:00Z");

  const [current, previous, twoAgo, allTimePnl, capitalInvested, balanceSheet, currentPnl] = await Promise.all([
    getExecutiveSummary(thisMonth, companyId),
    getExecutiveSummary(lastMonth, companyId),
    getExecutiveSummary(twoAgoRange, companyId),
    getProfitAndLoss({ from: allTimeFrom, to: now }, companyId),
    getCapitalInvested(now, companyId),
    getBalanceSheet(now, companyId),
    getProfitAndLoss(thisMonth, companyId),
  ]);

  return {
    current,
    previous,
    twoAgo,
    allTimeRevenue: allTimePnl.totalRevenue,
    allTimeExpense: allTimePnl.totalExpense,
    capitalInvested,
    balanceSheet,
    currentLeaves: leafRows(currentPnl.expense),
  };
}

// ---------------------------------------------------------------------
// Rules -- each looks at one dimension of the business and returns an
// insight only when its condition genuinely applies.
// ---------------------------------------------------------------------

function ruleBurnRate(d: Bundle): Insight | null {
  const avgMonthlyExpense = (d.current.totalExpense + d.previous.totalExpense + d.twoAgo.totalExpense) / 3;
  if (avgMonthlyExpense <= 0) return null;
  return {
    id: "burn-rate",
    title: "Burn Rate",
    severity: "opportunity",
    explanation: `You're currently spending about ${formatEGP(avgMonthlyExpense)} every month.`,
    whyItMatters: "This is the baseline your revenue needs to beat for the business to run on its own.",
    action: "Watch whether this is rising faster than your sales.",
    confidence: "Medium",
  };
}

function ruleRunway(d: Bundle): Insight | null {
  const avgMonthlyExpense = (d.current.totalExpense + d.previous.totalExpense + d.twoAgo.totalExpense) / 3;
  if (avgMonthlyExpense <= 0 || d.current.cashBalance <= 0) return null;
  const runway = d.current.cashBalance / avgMonthlyExpense;
  const severity: InsightSeverity = runway < 2 ? "critical" : runway < 4 ? "warning" : runway < 8 ? "opportunity" : "positive";
  return {
    id: "runway",
    title: "Runway",
    severity,
    explanation: `If nothing changes, your cash should last about ${formatMonths(runway)} months.`,
    whyItMatters: "This tells you how much time you have to reach your next milestone before cash runs out.",
    action: runway < 4 ? "Consider slowing discretionary spending or lining up your next capital contribution." : "Keep an eye on this as spending changes.",
    confidence: "Medium",
  };
}

function ruleNetMargin(d: Bundle): Insight | null {
  if (d.current.totalRevenue <= 0 && d.current.totalExpense <= 0) return null;
  if (d.current.netProfit < 0) {
    return {
      id: "net-margin",
      title: "Net Margin",
      severity: "warning",
      explanation: "You're spending more than you're earning right now.",
      whyItMatters: "This is the simplest sign of whether the business can support itself yet.",
      action: "Look for ways to grow revenue or trim costs to close the gap.",
      confidence: "High",
    };
  }
  const margin = pct(d.current.netProfit, d.current.totalRevenue);
  return {
    id: "net-margin",
    title: "Net Margin",
    severity: "positive",
    explanation: `You're earning more than you're spending right now -- about a ${margin}% margin this month.`,
    whyItMatters: "This is the simplest sign of whether the business can support itself yet.",
    action: "Keep monitoring this margin as you scale.",
    confidence: "High",
  };
}

function ruleOwnerEquity(d: Bundle): Insight | null {
  if (d.balanceSheet.totalEquity === 0) return null;
  const negative = d.balanceSheet.totalEquity < 0;
  return {
    id: "owner-equity",
    title: "Owner Equity",
    severity: negative ? "critical" : "opportunity",
    explanation: negative
      ? `Owner equity is negative (${formatEGP(d.balanceSheet.totalEquity)}) -- liabilities and losses now exceed what's been put in.`
      : `You currently have ${formatEGP(d.balanceSheet.totalEquity)} invested in your business.`,
    whyItMatters: "This is your ownership stake in the business today, after all profits, losses, and contributions.",
    action: negative ? "Address this before taking on further obligations." : "Watch how this moves as the business grows.",
    confidence: "High",
  };
}

function ruleCapitalUtilization(d: Bundle): Insight | null {
  if (d.capitalInvested <= 0 || d.balanceSheet.totalEquity >= d.capitalInvested) return null;
  const utilization = pct(d.capitalInvested - d.balanceSheet.totalEquity, d.capitalInvested);
  if (utilization < 10) return null;
  return {
    id: "capital-utilization",
    title: "Capital Utilization",
    severity: utilization >= 50 ? "warning" : "opportunity",
    explanation: `${utilization}% of the money you've invested has already been used to build the business.`,
    whyItMatters: "This shows how much of your runway you've already spent relative to what you put in.",
    action: utilization >= 50 ? "Keep a close eye on this -- you're over halfway through your invested capital." : "Keep watching this as you approach launch.",
    confidence: "High",
  };
}

function ruleInventoryConcentration(d: Bundle): Insight | null {
  if (d.current.totalExpense <= 0) return null;
  const materialSpend = d.currentLeaves.filter((r) => MATERIAL_LEAF_NAMES.has(r.name)).reduce((s, r) => s + r.amount, 0);
  const share = pct(materialSpend, d.current.totalExpense);
  if (share < 40) return null;
  return {
    id: "inventory-concentration",
    title: "Inventory Concentration",
    severity: share >= 70 ? "warning" : "opportunity",
    explanation: "Most of your money this month went into fabric and production.",
    whyItMatters: "Heavy investment in inventory ties up cash until it converts into sales.",
    action: "Keep an eye on how quickly this inventory turns into revenue.",
    confidence: "High",
  };
}

function ruleCashFlow(d: Bundle): Insight | null {
  if (d.current.totalExpense <= 0) return null;
  const top = [...d.currentLeaves]
    .filter((r) => !MATERIAL_LEAF_NAMES.has(r.name))
    .sort((a, b) => b.amount - a.amount)[0];
  if (!top) return null;
  const share = pct(top.amount, d.current.totalExpense);
  if (share < 20) return null;
  return {
    id: "cash-flow",
    title: "Cash Flow",
    severity: "opportunity",
    explanation: `Here's where your money went this month: ${share}% went to ${top.name}.`,
    whyItMatters: "Seeing your biggest spending category helps you decide where to cut back if needed.",
    action: "Compare this to last month to see if the pattern is shifting.",
    confidence: "High",
  };
}

function ruleLiquidity(d: Bundle): Insight | null {
  if (d.current.cashBalance <= 0) return null;
  const ratio = d.balanceSheet.totalLiabilities > 0 ? d.balanceSheet.totalLiabilities / d.current.cashBalance : 0;
  if (ratio >= 0.75) {
    return {
      id: "liquidity",
      title: "Liquidity",
      severity: ratio >= 1 ? "critical" : "warning",
      explanation: "Your upcoming bills are close to what you have in cash -- plan ahead.",
      whyItMatters: "This tells you whether short-term obligations could strain your cash position.",
      action: "Line up payment timing against expected collections before new obligations are added.",
      confidence: "High",
    };
  }
  return {
    id: "liquidity",
    title: "Liquidity",
    severity: "positive",
    explanation: "You have enough cash to keep operating for now.",
    whyItMatters: "This tells you whether short-term obligations could strain your cash position.",
    action: "No action needed right now.",
    confidence: "High",
  };
}

function ruleOperatingExpenses(d: Bundle): Insight | null {
  if (d.current.totalExpense <= 0) return null;
  const STRATEGIC = new Set(["COGS / Inventory", "Marketing & Ads"]);
  const strategic = d.current.expenseByCategory.filter((c) => STRATEGIC.has(c.category)).reduce((s, c) => s + c.amount, 0);
  const operating = d.current.totalExpense - strategic;
  if (operating <= 0) return null;
  return {
    id: "operating-expenses",
    title: "Operating Expenses",
    severity: "opportunity",
    explanation: `You spent ${formatEGP(operating)} this month on operating costs like rent, salaries, and subscriptions -- money spent to keep the business running.`,
    whyItMatters: "These costs happen regardless of sales volume, so they set your minimum monthly burn.",
    action: "Review this list occasionally for costs that no longer serve the business.",
    confidence: "Medium",
  };
}

function ruleRevenueTrend(d: Bundle): Insight | null {
  if (d.previous.totalRevenue <= 0) return null;
  const growth = (d.current.totalRevenue - d.previous.totalRevenue) / d.previous.totalRevenue;
  const growthPct = Math.abs(Math.round(growth * 100));
  if (growth > 0.05) {
    return {
      id: "revenue-trend",
      title: "Revenue Trend",
      severity: "positive",
      explanation: `Sales are growing -- up ${growthPct}% compared to last month.`,
      whyItMatters: "Revenue direction is the clearest signal of momentum, good or bad.",
      action: "Identify what drove the increase and double down on it.",
      confidence: "Medium",
    };
  }
  if (growth < -0.05) {
    return {
      id: "revenue-trend",
      title: "Revenue Trend",
      severity: "warning",
      explanation: `Sales are slowing down -- down ${growthPct}% compared to last month.`,
      whyItMatters: "Revenue direction is the clearest signal of momentum, good or bad.",
      action: "Look into what changed and whether it's temporary.",
      confidence: "Medium",
    };
  }
  return {
    id: "revenue-trend",
    title: "Revenue Trend",
    severity: "opportunity",
    explanation: "Sales are holding steady compared to last month.",
    whyItMatters: "Revenue direction is the clearest signal of momentum, good or bad.",
    action: "Keep tracking month to month for a clearer trend.",
    confidence: "Medium",
  };
}

function ruleProfitability(d: Bundle): Insight | null {
  if (d.allTimeRevenue <= 0 && d.allTimeExpense <= 0) return null;
  const allTimeNet = d.allTimeRevenue - d.allTimeExpense;

  if (d.allTimeRevenue <= 0) {
    return {
      id: "profitability",
      title: "Profitability",
      severity: "critical",
      explanation: `Not yet -- you've spent ${formatEGP(d.allTimeExpense)} but haven't earned any revenue so far.`,
      whyItMatters: "This is the big-picture answer, not just this month's snapshot.",
      action: "Focus on reaching your first paying sales.",
      confidence: "High",
    };
  }

  if (allTimeNet > 0) {
    return {
      id: "profitability",
      title: "Profitability",
      severity: "positive",
      explanation: `Yes -- you've earned ${formatEGP(allTimeNet)} more than you've spent since starting.`,
      whyItMatters: "This is the big-picture answer, not just this month's snapshot.",
      action: "Keep reinvesting to sustain this.",
      confidence: "High",
    };
  }

  return {
    id: "profitability",
    title: "Profitability",
    severity: "warning",
    explanation: `Not yet -- you've spent ${formatEGP(Math.abs(allTimeNet))} more than you've earned since starting.`,
    whyItMatters: "This is the big-picture answer, not just this month's snapshot.",
    action: "Focus on reaching your next profitable month.",
    confidence: "High",
  };
}

const RULES: Array<(d: Bundle) => Insight | null> = [
  ruleProfitability,
  ruleLiquidity,
  ruleRunway,
  ruleNetMargin,
  ruleRevenueTrend,
  ruleCapitalUtilization,
  ruleInventoryConcentration,
  ruleBurnRate,
  ruleOwnerEquity,
  ruleCashFlow,
  ruleOperatingExpenses,
];

export async function getAIInsights(companyId = DEFAULT_COMPANY_ID): Promise<Insight[]> {
  const bundle = await buildBundle(companyId);
  const insights = RULES.map((rule) => rule(bundle)).filter((i): i is Insight => i !== null);
  return insights.sort((a, b) => SEVERITY_ORDER[a.severity] - SEVERITY_ORDER[b.severity]);
}
