import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID } from "./company";
import {
  getExecutiveSummary,
  getBalanceSheet,
  getProfitAndLoss,
  getAccountBalance,
  type ExecutiveSummary,
  type AccountRollupRow,
} from "./reports";
import { getAccountByCode } from "./ledger";
import { getCapitalInvested } from "../modules/capital";
import { CHART_OF_ACCOUNTS, type AccountSeedNode } from "./chartOfAccountsSeed";
import { addMonths, startOfCairoMonth, endOfCairoMonth } from "../dates";
import { formatEGP } from "../currency";

// Plain-language, CFO-style analysis of the business -- distinct from the
// Business Health Score's weighted 0-100 formula. Every insight here is a
// deterministic rule over real ledger data (never invented, never a live
// model call), so the feed is reproducible and free to compute on every
// Dashboard load -- it simply reflects whatever the ledger currently says.

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

type Bundle = {
  current: ExecutiveSummary;
  previous: ExecutiveSummary;
  twoAgo: ExecutiveSummary;
  allTimeRevenue: number;
  allTimeExpense: number;
  allTimeExpenseLeaves: AccountRollupRow[];
  capitalInvested: number;
  balanceSheet: Awaited<ReturnType<typeof getBalanceSheet>>;
  currentLeaves: AccountRollupRow[];
  previousLeaves: AccountRollupRow[];
  inventoryValue: number;
  topSupplier: { name: string; amount: number; shareOfExpense: number } | null;
};

async function getTopSupplier(from: Date, to: Date, totalExpense: number, companyId: string) {
  const lines = await prisma.journalLine.groupBy({
    by: ["supplierId"],
    where: {
      companyId,
      supplierId: { not: null },
      account: { type: "EXPENSE" },
      journalEntry: { date: { gte: from, lte: to } },
    },
    _sum: { debit: true },
  });
  if (lines.length === 0) return null;

  const top = lines.reduce((best, l) => (Number(l._sum.debit) > Number(best._sum.debit) ? l : best));
  if (!top.supplierId || Number(top._sum.debit) <= 0) return null;

  const supplier = await prisma.supplier.findUnique({ where: { id: top.supplierId } });
  if (!supplier) return null;

  const amount = Number(top._sum.debit);
  return { name: supplier.name, amount, shareOfExpense: pct(amount, totalExpense) };
}

async function buildBundle(companyId: string): Promise<Bundle> {
  const now = new Date();
  const thisMonth = { from: startOfCairoMonth(now), to: endOfCairoMonth(now) };
  const lastMonthDate = addMonths(now, -1);
  const lastMonth = { from: startOfCairoMonth(lastMonthDate), to: endOfCairoMonth(lastMonthDate) };
  const twoAgoDate = addMonths(now, -2);
  const twoAgoRange = { from: startOfCairoMonth(twoAgoDate), to: endOfCairoMonth(twoAgoDate) };
  const allTimeFrom = new Date("2000-01-01T00:00:00Z");

  const [
    current,
    previous,
    twoAgo,
    allTimePnl,
    capitalInvested,
    balanceSheet,
    currentPnl,
    previousPnl,
    rawInventory,
    finishedInventory,
  ] = await Promise.all([
    getExecutiveSummary(thisMonth, companyId),
    getExecutiveSummary(lastMonth, companyId),
    getExecutiveSummary(twoAgoRange, companyId),
    getProfitAndLoss({ from: allTimeFrom, to: now }, companyId),
    getCapitalInvested(now, companyId),
    getBalanceSheet(now, companyId),
    getProfitAndLoss(thisMonth, companyId),
    getProfitAndLoss(lastMonth, companyId),
    getAccountByCode("1200", companyId).then((a) => getAccountBalance(a.id, now, companyId)),
    getAccountByCode("1210", companyId).then((a) => getAccountBalance(a.id, now, companyId)),
  ]);

  // Needs current.totalExpense, so it runs after the batch above resolves.
  const topSupplier = await getTopSupplier(thisMonth.from, thisMonth.to, current.totalExpense, companyId).catch(() => null);

  return {
    current,
    previous,
    twoAgo,
    allTimeRevenue: allTimePnl.totalRevenue,
    allTimeExpense: allTimePnl.totalExpense,
    allTimeExpenseLeaves: leafRows(allTimePnl.expense),
    capitalInvested,
    balanceSheet,
    currentLeaves: leafRows(currentPnl.expense),
    previousLeaves: leafRows(previousPnl.expense),
    inventoryValue: rawInventory + finishedInventory,
    topSupplier,
  };
}

// ---------------------------------------------------------------------
// Rules -- each looks at one dimension of the business and returns an
// insight only when its condition genuinely applies.
// ---------------------------------------------------------------------

function ruleNoRevenueYet(d: Bundle): Insight | null {
  if (d.allTimeRevenue > 0 || d.allTimeExpense <= 0) return null;
  return {
    id: "no-revenue-yet",
    title: "Pre-Revenue Stage",
    severity: "critical",
    explanation: `Your business has not generated any revenue yet while spending ${formatEGP(d.allTimeExpense)}.`,
    whyItMatters: "Every EGP spent so far is funded entirely by capital, not sales, so your runway is finite until revenue starts.",
    action: "Prioritize launching and selling before adding new operating expenses.",
    confidence: "High",
  };
}

function ruleTopCategoryConcentration(d: Bundle): Insight | null {
  if (d.current.totalExpense <= 0) return null;
  const top = [...d.currentLeaves].sort((a, b) => b.amount - a.amount)[0];
  if (!top) return null;
  const share = pct(top.amount, d.current.totalExpense);
  if (share < 35) return null;

  const isCogsMaterial = top.name === "Fabric" || top.name === "Sample Production";
  return {
    id: "top-category-concentration",
    title: `${top.name} Dominates This Month's Spending`,
    severity: share >= 55 ? "warning" : "opportunity",
    explanation: `${top.name} purchases account for ${share}% of all spending this month.`,
    whyItMatters: "Concentrating spend in one category means your cash flow is highly sensitive to that category's costs.",
    action: isCogsMaterial
      ? "Monitor supplier costs closely before committing to further production."
      : `Review ${top.name} spending before it grows further.`,
    confidence: "High",
  };
}

function ruleSpendingAcceleration(d: Bundle): Insight | null {
  if (d.previous.totalExpense <= 0) return null;
  const growth = (d.current.totalExpense - d.previous.totalExpense) / d.previous.totalExpense;
  if (growth < 0.3) return null;

  const prevByCode = new Map(d.previousLeaves.map((r) => [r.code, r.amount]));
  const driver = [...d.currentLeaves]
    .map((r) => ({ ...r, delta: r.amount - (prevByCode.get(r.code) ?? 0) }))
    .sort((a, b) => b.delta - a.delta)[0];

  return {
    id: "spending-acceleration",
    title: "Spending Accelerated Sharply",
    severity: "warning",
    explanation: `Your spending grew ${Math.round(growth * 100)}% compared to last month${
      driver && driver.delta > 0 ? `, mostly driven by ${driver.name}` : ""
    }.`,
    whyItMatters: "A sudden jump in the burn rate shortens your runway faster than steady growth would.",
    action: driver ? `Confirm the increase in ${driver.name} was planned before it repeats next month.` : "Review this month's expenses line by line.",
    confidence: "High",
  };
}

function ruleCapitalErosion(d: Bundle): Insight | null {
  if (d.capitalInvested <= 0 || d.balanceSheet.totalEquity >= d.capitalInvested) return null;
  const erosion = pct(d.capitalInvested - d.balanceSheet.totalEquity, d.capitalInvested);
  if (erosion < 20) return null;
  return {
    id: "capital-erosion",
    title: "Capital Is Converting Into Spend",
    severity: erosion >= 50 ? "warning" : "opportunity",
    explanation: `You invested ${formatEGP(d.capitalInvested)} but only ${formatEGP(
      d.balanceSheet.totalEquity
    )} remains as owner equity -- ${erosion}% of your capital has already become business assets or expenses.`,
    whyItMatters: "This is expected pre-revenue, but it shows how much runway you've already used relative to what you put in.",
    action: erosion >= 50 ? "Track this closely -- you're over halfway through your invested capital." : "Keep watching this ratio as you approach launch.",
    confidence: "High",
  };
}

function ruleEquityGrowth(d: Bundle): Insight | null {
  if (d.capitalInvested <= 0 || d.balanceSheet.totalEquity <= d.capitalInvested) return null;
  const growth = pct(d.balanceSheet.totalEquity - d.capitalInvested, d.capitalInvested);
  return {
    id: "equity-growth",
    title: "Owner Equity Has Grown Beyond Capital Invested",
    severity: "positive",
    explanation: `Owner equity (${formatEGP(d.balanceSheet.totalEquity)}) now exceeds the ${formatEGP(
      d.capitalInvested
    )} you invested, by ${growth}%.`,
    whyItMatters: "The business has created value beyond what was put in -- a genuine sign of profitability.",
    action: "Keep reinvesting retained earnings rather than drawing them down too early.",
    confidence: "High",
  };
}

function ruleSubscriptionCreep(d: Bundle): Insight | null {
  if (d.current.totalExpense <= 0) return null;
  const subs = d.current.expenseByCategory.find((c) => c.category === "Software & Subscriptions");
  if (!subs) return null;
  const share = pct(subs.amount, d.current.totalExpense);
  if (share < 3) return null;
  return {
    id: "subscription-creep",
    title: "Software Subscriptions Are Growing",
    severity: share >= 5 ? "warning" : "opportunity",
    explanation: `Software subscriptions represent ${share}% of this month's operating costs.`,
    whyItMatters: "Recurring costs compound quietly and are easy to lose track of once several tools stack up.",
    action: "Review active subscriptions before this crosses 5% of monthly operating costs.",
    confidence: "Medium",
  };
}

function ruleCashRunway(d: Bundle): Insight | null {
  const avgMonthlyExpense = (d.current.totalExpense + d.previous.totalExpense + d.twoAgo.totalExpense) / 3;
  if (avgMonthlyExpense <= 0 || d.current.cashBalance <= 0) return null;
  const runway = d.current.cashBalance / avgMonthlyExpense;

  const severity: InsightSeverity = runway < 2 ? "critical" : runway < 4 ? "warning" : runway < 8 ? "opportunity" : "positive";
  return {
    id: "cash-runway",
    title: runway < 4 ? "Runway Is Getting Short" : "Cash Runway",
    severity,
    explanation: `At your current burn rate of ${formatEGP(avgMonthlyExpense)}/month, available cash covers approximately ${runway.toFixed(
      1
    )} months of operations.`,
    whyItMatters: runway < 4 ? "Under 4 months of runway leaves little room to react if revenue is delayed." : "Knowing your runway tells you how much time you have to reach your next milestone.",
    action: runway < 4 ? "Slow discretionary spending or plan your next capital contribution now." : "Continue monitoring monthly burn against this runway.",
    confidence: "Medium",
  };
}

function ruleCashDecline(d: Bundle): Insight | null {
  if (d.previous.cashBalance <= 0 || d.current.cashBalance >= d.previous.cashBalance) return null;
  const decline = pct(d.previous.cashBalance - d.current.cashBalance, d.previous.cashBalance);
  if (decline < 10) return null;
  return {
    id: "cash-decline",
    title: "Cash Reserves Declined This Month",
    severity: decline >= 25 ? "critical" : "warning",
    explanation: `Cash reserves decreased by ${decline}% this month.`,
    whyItMatters: "A fast decline in cash, even while profitable on paper, can create a liquidity problem before it shows up elsewhere.",
    action: "Compare this to your runway estimate and confirm the decline matches planned spending.",
    confidence: "High",
  };
}

function ruleInventoryHeavy(d: Bundle): Insight | null {
  if (d.balanceSheet.totalAssets <= 0 || d.inventoryValue <= 0) return null;
  const share = pct(d.inventoryValue, d.balanceSheet.totalAssets);
  if (share < 50) return null;
  return {
    id: "inventory-heavy-assets",
    title: "Inventory Dominates Your Balance Sheet",
    severity: "opportunity",
    explanation: `Inventory represents ${share}% of total assets.`,
    whyItMatters: "This is expected before launch, but once you're selling, unsold inventory ties up cash that could fund operations.",
    action: "Make inventory turnover your next KPI once sales begin.",
    confidence: "High",
  };
}

function rulePrototypingHeavy(d: Bundle): Insight | null {
  const samples = d.allTimeExpenseLeaves.find((r) => r.name === "Sample Production")?.amount ?? 0;
  const production = d.allTimeExpenseLeaves
    .filter((r) => r.name === "Production" || r.name === "Fabric")
    .reduce((sum, r) => sum + r.amount, 0);
  if (samples <= 0 || samples < production) return null;
  return {
    id: "prototyping-heavy",
    title: "Spending Is Still Prototype-Heavy",
    severity: "opportunity",
    explanation: `Sample production (${formatEGP(samples)}) has cost more than fabric and production combined (${formatEGP(production)}) so far.`,
    whyItMatters: "Prototyping is necessary early on, but it doesn't generate sellable inventory.",
    action: "Shift future spend toward production runs rather than additional samples once designs are finalized.",
    confidence: "Medium",
  };
}

function ruleLiabilitiesVsCash(d: Bundle): Insight | null {
  if (d.balanceSheet.totalLiabilities <= 0 || d.current.cashBalance <= 0) return null;
  const ratio = d.balanceSheet.totalLiabilities / d.current.cashBalance;
  if (ratio < 0.75) return null;
  return {
    id: "liabilities-vs-cash",
    title: "Liabilities Are Close to Available Cash",
    severity: ratio >= 1 ? "warning" : "opportunity",
    explanation: `Liabilities (${formatEGP(d.balanceSheet.totalLiabilities)}) are ${
      ratio >= 1 ? "higher than" : "close to"
    } your available cash (${formatEGP(d.current.cashBalance)}).`,
    whyItMatters: "If suppliers or loans come due before you collect revenue, this gap becomes a real cash crunch.",
    action: "Line up payment timing against expected collections before new obligations are added.",
    confidence: "High",
  };
}

function ruleTopSupplier(d: Bundle): Insight | null {
  if (!d.topSupplier || d.topSupplier.shareOfExpense < 35) return null;
  return {
    id: "top-supplier-concentration",
    title: `${d.topSupplier.name} Is Your Largest Supplier`,
    severity: d.topSupplier.shareOfExpense >= 60 ? "warning" : "opportunity",
    explanation: `${d.topSupplier.name} represents ${d.topSupplier.shareOfExpense}% of this month's purchasing.`,
    whyItMatters: "Depending heavily on one supplier creates pricing and delivery risk you don't control.",
    action: "Consider a backup supplier for critical materials before scaling orders further.",
    confidence: "Medium",
  };
}

function ruleStrategicSpend(d: Bundle): Insight | null {
  if (d.current.totalExpense <= 0) return null;
  const STRATEGIC = new Set(["COGS / Inventory", "Marketing & Ads"]);
  const strategic = d.current.expenseByCategory.filter((c) => STRATEGIC.has(c.category)).reduce((s, c) => s + c.amount, 0);
  const operating = d.current.totalExpense - strategic;
  if (strategic <= operating || strategic <= 0) return null;
  return {
    id: "strategic-spend",
    title: "This Month Was Investment-Heavy",
    severity: "positive",
    explanation: `${pct(strategic, d.current.totalExpense)}% of this month's expenses went to inventory and marketing rather than fixed operating costs.`,
    whyItMatters: "Spending that builds inventory or demand is different from pure overhead -- it's working toward future revenue.",
    action: "Keep tracking whether this spend converts into sales over the next 1-2 months.",
    confidence: "Medium",
  };
}

function ruleRevenueGrowth(d: Bundle): Insight | null {
  if (d.previous.totalRevenue <= 0) return null;
  const revenueGrowth = (d.current.totalRevenue - d.previous.totalRevenue) / d.previous.totalRevenue;
  const expenseGrowth = d.previous.totalExpense > 0 ? (d.current.totalExpense - d.previous.totalExpense) / d.previous.totalExpense : 0;
  if (revenueGrowth < 0.15 || revenueGrowth <= expenseGrowth) return null;
  return {
    id: "revenue-growth",
    title: "Revenue Is Outpacing Expenses",
    severity: "positive",
    explanation: `Revenue grew ${Math.round(revenueGrowth * 100)}% this month, ahead of expense growth of ${Math.round(expenseGrowth * 100)}%.`,
    whyItMatters: "Revenue growing faster than costs is the clearest sign your unit economics are improving.",
    action: "Identify what drove the growth and double down on it.",
    confidence: "High",
  };
}

function ruleFlatRevenueRisingProduction(d: Bundle): Insight | null {
  const currentProduction = d.currentLeaves
    .filter((r) => r.name === "Production" || r.name === "Fabric")
    .reduce((s, r) => s + r.amount, 0);
  const previousProduction = d.previousLeaves
    .filter((r) => r.name === "Production" || r.name === "Fabric")
    .reduce((s, r) => s + r.amount, 0);
  if (previousProduction <= 0 || currentProduction <= previousProduction * 1.2) return null;
  const revenueFlat = d.previous.totalRevenue <= 0 || Math.abs(d.current.totalRevenue - d.previous.totalRevenue) / d.previous.totalRevenue < 0.1;
  if (!revenueFlat) return null;
  return {
    id: "production-up-revenue-flat",
    title: "Production Costs Rising Without Matching Sales",
    severity: "warning",
    explanation: "Fabric and production costs increased this month while revenue stayed roughly flat.",
    whyItMatters: "Growing COGS without growing revenue compresses margin and eats into runway faster.",
    action: "Confirm the added production has committed orders behind it before increasing further.",
    confidence: "Medium",
  };
}

const RULES: Array<(d: Bundle) => Insight | null> = [
  ruleNoRevenueYet,
  ruleCashDecline,
  ruleCashRunway,
  ruleFlatRevenueRisingProduction,
  ruleSpendingAcceleration,
  ruleLiabilitiesVsCash,
  ruleTopCategoryConcentration,
  ruleTopSupplier,
  ruleCapitalErosion,
  ruleSubscriptionCreep,
  rulePrototypingHeavy,
  ruleInventoryHeavy,
  ruleEquityGrowth,
  ruleRevenueGrowth,
  ruleStrategicSpend,
];

export async function getAIInsights(companyId = DEFAULT_COMPANY_ID): Promise<Insight[]> {
  const bundle = await buildBundle(companyId);
  const insights = RULES.map((rule) => rule(bundle)).filter((i): i is Insight => i !== null);
  return insights.sort((a, b) => SEVERITY_ORDER[a.severity] - SEVERITY_ORDER[b.severity]);
}
