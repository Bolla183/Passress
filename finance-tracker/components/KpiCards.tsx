import { formatEGP } from "@/lib/currency";

type Kpi = {
  label: string;
  value: number;
  tone?: "income" | "expense" | "neutral";
  format?: "currency" | "percent";
};

export default function KpiCards({ kpis }: { kpis: Kpi[] }) {
  return (
    <div className="mb-8 grid grid-cols-2 gap-px border border-hairline bg-hairline">
      {kpis.map((kpi) => (
        <div key={kpi.label} className="bg-paper px-3 py-4 text-center">
          <p className="mb-1 text-xs uppercase tracking-widest text-muted">{kpi.label}</p>
          <p
            className={`text-sm sm:text-base ${
              kpi.tone === "income" ? "text-income" : kpi.tone === "expense" ? "text-expense" : ""
            }`}
          >
            {kpi.format === "percent" ? `${kpi.value.toFixed(1)}%` : formatEGP(kpi.value)}
          </p>
        </div>
      ))}
    </div>
  );
}
