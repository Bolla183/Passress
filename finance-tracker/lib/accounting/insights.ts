import { DEFAULT_COMPANY_ID } from "./company";
import { getExecutiveSummary, getBalanceSheet } from "./reports";
import { getCapitalInvested } from "../modules/capital";
import { formatEGP } from "../currency";
import { addMonths, startOfCairoMonth, endOfCairoMonth } from "../dates";

// Plain-language statements about the business, distinct from the Business
// Health Score's short "why" -- every sentence maps to a value the reports
// engine already computes (ownership from Balance Sheet equity, composition
// from expense-by-category, comparisons from the same period-over-period
// deltas used elsewhere), never invented.
export async function getDashboardInsights(companyId = DEFAULT_COMPANY_ID): Promise<string[]> {
  const now = new Date();
  const thisMonth = { from: startOfCairoMonth(now), to: endOfCairoMonth(now) };
  const lastMonthDate = addMonths(now, -1);
  const lastMonth = { from: startOfCairoMonth(lastMonthDate), to: endOfCairoMonth(lastMonthDate) };

  const [current, previous, capitalInvested, balanceSheet] = await Promise.all([
    getExecutiveSummary(thisMonth, companyId),
    getExecutiveSummary(lastMonth, companyId),
    getCapitalInvested(now, companyId),
    getBalanceSheet(now, companyId),
  ]);

  const insights: string[] = [];

  if (capitalInvested > 0) {
    insights.push(`You've invested ${formatEGP(capitalInvested)} into your business.`);
  }
  insights.push(`Current owner equity is ${formatEGP(balanceSheet.totalEquity)}.`);

  const topExpense = current.expenseByCategory[0];
  if (topExpense && current.totalExpense > 0) {
    const pct = Math.round((topExpense.amount / current.totalExpense) * 100);
    insights.push(`${topExpense.category} represents ${pct}% of your expenses this month.`);
  }

  if (previous.totalRevenue > 0) {
    const growth = Math.round(((current.totalRevenue - previous.totalRevenue) / previous.totalRevenue) * 100);
    if (growth !== 0) {
      insights.push(`Revenue ${growth > 0 ? "increased" : "decreased"} ${Math.abs(growth)}% compared to last month.`);
    }
  }

  if (previous.cashBalance > 0) {
    const cashChange = Math.round(((current.cashBalance - previous.cashBalance) / previous.cashBalance) * 100);
    if (Math.abs(cashChange) >= 5) {
      insights.push(`Cash balance ${cashChange > 0 ? "increased" : "decreased"} by ${Math.abs(cashChange)}% since last month.`);
    }
  }

  return insights.slice(0, 4);
}
