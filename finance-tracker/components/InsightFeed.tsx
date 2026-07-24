import type { Insight, InsightSeverity } from "@/lib/accounting/insights";

const SEVERITY_META: Record<InsightSeverity, { emoji: string; label: string; color: string; bg: string }> = {
  critical: { emoji: "🔴", label: "Critical", color: "text-critical", bg: "bg-critical-bg" },
  warning: { emoji: "🟠", label: "Warning", color: "text-warning", bg: "bg-warning-bg" },
  positive: { emoji: "🟢", label: "Positive", color: "text-positive", bg: "bg-positive-bg" },
  opportunity: { emoji: "🔵", label: "Opportunity", color: "text-opportunity", bg: "bg-opportunity-bg" },
};

const BORDER_COLOR: Record<InsightSeverity, string> = {
  critical: "border-l-critical",
  warning: "border-l-warning",
  positive: "border-l-positive",
  opportunity: "border-l-opportunity",
};

function InsightRow({ insight }: { insight: Insight }) {
  const meta = SEVERITY_META[insight.severity];
  return (
    <div className={`rounded-2xl border border-hairline border-l-4 ${BORDER_COLOR[insight.severity]} bg-paper p-4 shadow-sm`}>
      <div className="mb-2 flex items-center justify-between">
        <span className={`inline-flex items-center gap-1 rounded-full ${meta.bg} px-2 py-0.5 text-xs font-medium ${meta.color}`}>
          {meta.emoji} {meta.label}
        </span>
        <span className="text-xs uppercase tracking-widest text-muted">{insight.confidence} confidence</span>
      </div>
      <p className="mb-1 text-sm font-semibold">{insight.title}</p>
      <p className="mb-2 text-sm">{insight.explanation}</p>
      <p className="mb-1 text-xs text-muted">
        <span className="font-medium text-ink">Why it matters: </span>
        {insight.whyItMatters}
      </p>
      <p className="text-xs text-muted">
        <span className="font-medium text-ink">Suggested action: </span>
        {insight.action}
      </p>
    </div>
  );
}

export default function InsightFeed({ insights }: { insights: Insight[] }) {
  if (insights.length === 0) {
    return (
      <div className="mb-6">
        <p className="mb-2 text-xs uppercase tracking-widest text-muted">AI Insight Feed</p>
        <p className="rounded-2xl border border-hairline bg-paper p-4 text-sm text-muted shadow-sm">
          Nothing notable yet -- check back as more activity is recorded.
        </p>
      </div>
    );
  }

  return (
    <div className="mb-6">
      <p className="mb-2 text-xs uppercase tracking-widest text-muted">AI Insight Feed</p>
      <div className="flex flex-col gap-3">
        {insights.map((insight) => (
          <InsightRow key={insight.id} insight={insight} />
        ))}
      </div>
    </div>
  );
}
