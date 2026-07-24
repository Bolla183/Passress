import { startOfCairoMonth, endOfCairoMonth, startOfCairoDay, endOfCairoDay, addMonths, monthLabel } from "@/lib/dates";
import { getExecutiveSummary, getMonthlyTrend, getProfitAndLoss, getBalanceSheet } from "@/lib/accounting/reports";
import { getCapitalInvested } from "@/lib/modules/capital";
import { getBusinessHealth } from "@/lib/accounting/healthScore";
import { getDashboardInsights } from "@/lib/accounting/insights";
import { getRecentActivity } from "@/lib/accounting/activityFeed";
import HeroMetric from "@/components/HeroMetric";
import TodayCard from "@/components/TodayCard";
import KpiCards from "@/components/KpiCards";
import HealthScoreCard from "@/components/HealthScoreCard";
import PerformanceAreaChart from "@/components/PerformanceAreaChart";
import ActivityPreview from "@/components/ActivityPreview";
import InsightsCard from "@/components/InsightsCard";

export const dynamic = "force-dynamic";

function pctChange(current: number, previous: number): number | null {
  if (previous === 0) return current === 0 ? 0 : null;
  return ((current - previous) / Math.abs(previous)) * 100;
}

const TREND_MONTHS_BACK = 11;

export default async function DashboardPage() {
  const now = new Date();
  const thisMonth = { from: startOfCairoMonth(now), to: endOfCairoMonth(now) };
  const lastMonthDate = addMonths(now, -1);
  const lastMonth = { from: startOfCairoMonth(lastMonthDate), to: endOfCairoMonth(lastMonthDate) };
  const today = { from: startOfCairoDay(now), to: endOfCairoDay(now) };

  const months: { start: Date; end: Date; label: string }[] = [];
  for (let i = TREND_MONTHS_BACK; i >= 0; i -= 1) {
    const d = addMonths(now, -i);
    months.push({ start: startOfCairoMonth(d), end: endOfCairoMonth(d), label: monthLabel(d) });
  }

  const [current, previous, todayPnl, capitalInvested, balanceSheet, health, trend, insights, activity] =
    await Promise.all([
      getExecutiveSummary(thisMonth),
      getExecutiveSummary(lastMonth),
      getProfitAndLoss(today),
      getCapitalInvested(now),
      getBalanceSheet(now),
      getBusinessHealth(),
      getMonthlyTrend(months),
      getDashboardInsights(),
      getRecentActivity(4),
    ]);

  const netProfitDelta = pctChange(current.netProfit, previous.netProfit);
  const revenueDelta = pctChange(current.totalRevenue, previous.totalRevenue);
  const expenseDelta = pctChange(current.totalExpense, previous.totalExpense);

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-6 text-lg tracking-widest uppercase">Dashboard</h1>

      <HeroMetric label="Cash Available" value={current.cashBalance} sublabel="as of today" />

      <TodayCard revenue={todayPnl.totalRevenue} expense={todayPnl.totalExpense} profit={todayPnl.netProfit} />

      <KpiCards
        kpis={[
          { label: "Net Profit", value: current.netProfit, tone: current.netProfit >= 0 ? "income" : "expense", delta: netProfitDelta },
          { label: "Capital Invested", value: capitalInvested },
          { label: "Owner Equity", value: balanceSheet.totalEquity },
        ]}
      />

      <HealthScoreCard score={health.score} band={health.band} why={health.why} />

      <KpiCards
        columns={2}
        kpis={[
          { label: "Revenue", value: current.totalRevenue, tone: "income", delta: revenueDelta },
          { label: "Expenses", value: current.totalExpense, tone: "expense", delta: expenseDelta },
        ]}
      />

      <p className="mb-2 text-xs uppercase tracking-widest text-muted">Revenue vs Expense, last 12 months</p>
      <div className="mb-8 rounded-2xl border border-hairline p-3 shadow-sm">
        <PerformanceAreaChart data={trend} />
      </div>

      <ActivityPreview items={activity} />

      <InsightsCard insights={insights} />
    </div>
  );
}
