import { formatEGP } from "@/lib/currency";

export default function HeroMetric({
  label,
  value,
  delta,
  sublabel,
}: {
  label: string;
  value: number;
  delta?: number | null;
  sublabel: string;
}) {
  const positive = value >= 0;
  return (
    <div className="mb-6 rounded-3xl border border-hairline bg-paper px-6 py-8 text-center shadow-sm">
      <p className="mb-2 text-xs uppercase tracking-widest text-muted">{label}</p>
      <p className={`text-4xl font-semibold tabular-nums sm:text-5xl ${positive ? "text-income" : "text-expense"}`}>
        {formatEGP(value)}
      </p>
      <div className="mt-3 flex items-center justify-center gap-2 text-xs">
        {delta !== undefined && delta !== null && (
          <span className={delta >= 0 ? "text-income" : "text-expense"}>
            {delta >= 0 ? "▲" : "▼"} {Math.abs(delta).toFixed(0)}%
          </span>
        )}
        <span className="text-muted">{sublabel}</span>
      </div>
    </div>
  );
}
