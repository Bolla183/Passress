import Link from "next/link";

export default function HealthScoreCard({
  score,
  band,
  why,
}: {
  score: number;
  band: string;
  why: string[];
}) {
  return (
    <Link href="/health" className="mb-6 flex items-center gap-4 rounded-2xl border border-hairline bg-paper p-5 shadow-sm">
      <div className="shrink-0 text-center">
        <p className="text-3xl font-semibold tabular-nums text-accent leading-none">
          {score}
          <span className="text-base font-normal text-muted">/100</span>
        </p>
      </div>
      <div className="min-w-0 flex-1">
        <p className="mb-0.5 text-xs font-bold uppercase tracking-widest text-accent">{band}</p>
        <p className="text-xs leading-relaxed text-muted">{why.join(" · ")}</p>
      </div>
      <span className="shrink-0 text-hairline">›</span>
    </Link>
  );
}
