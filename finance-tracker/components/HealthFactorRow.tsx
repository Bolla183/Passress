import type { HealthFactor } from "@/lib/accounting/healthScore";
import { sentenceFor, toneFor } from "@/lib/accounting/healthScore";

function barToneFor(score: number): "income" | "accent" | "expense" {
  if (score >= 70) return "income";
  if (score >= 40) return "accent";
  return "expense";
}

export default function HealthFactorRow({ factor }: { factor: HealthFactor }) {
  const barTone = barToneFor(factor.score);
  const barColor = barTone === "income" ? "bg-income" : barTone === "expense" ? "bg-expense" : "bg-accent";
  const textColor = barTone === "income" ? "text-income" : barTone === "expense" ? "text-expense" : "text-accent";

  return (
    <div className="mb-4 rounded-2xl border border-hairline bg-paper p-4 shadow-sm">
      <div className="mb-2 flex items-center justify-between">
        <p className="text-sm font-medium">{factor.name}</p>
        <p className={`text-sm font-medium tabular-nums ${textColor}`}>{Math.round(factor.score)}/100</p>
      </div>
      <div className="mb-2 h-1.5 overflow-hidden rounded-full bg-hairline">
        <div className={`h-full rounded-full ${barColor}`} style={{ width: `${Math.max(0, Math.min(100, factor.score))}%` }} />
      </div>
      <p className="text-xs text-muted">
        {sentenceFor(factor, toneFor(factor.score))} · {Math.round(factor.weight * 100)}% weight
      </p>
    </div>
  );
}
