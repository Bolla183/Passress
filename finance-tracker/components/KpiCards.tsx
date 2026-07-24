import { formatEGP } from "@/lib/currency";

type Kpi = {
  label: string;
  value: number;
  tone?: "income" | "expense" | "neutral";
  format?: "currency" | "percent";
  delta?: number | null;
};

function DeltaBadge({ delta }: { delta: number }) {
  const up = delta >= 0;
  return (
    <span className={`text-xs ${up ? "text-income" : "text-expense"}`}>
      {up ? "▲" : "▼"} {Math.abs(delta).toFixed(0)}%
    </span>
  );
}

export default function KpiCards({ kpis }: { kpis: Kpi[] }) {
  return (
    <div className="mb-8 grid grid-cols-3 gap-3">
      {kpis.map((kpi) => (
        <div key={kpi.label} className="rounded-2xl border border-hairline bg-paper px-3 py-4 text-center shadow-sm">
          <p className="mb-1 text-xs uppercase tracking-widest text-muted">{kpi.label}</p>
          <p
            className={`text-sm font-medium sm:text-base ${
              kpi.tone === "income" ? "text-income" : kpi.tone === "expense" ? "text-expense" : ""
            }`}
          >
            {kpi.format === "percent" ? `${kpi.value.toFixed(1)}%` : formatEGP(kpi.value)}
          </p>
          {kpi.delta !== undefined && kpi.delta !== null && (
            <div className="mt-1">
              <DeltaBadge delta={kpi.delta} />
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
