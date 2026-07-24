import Link from "next/link";
import { getBusinessHealth } from "@/lib/accounting/healthScore";
import HealthFactorRow from "@/components/HealthFactorRow";

export const dynamic = "force-dynamic";

export default async function HealthPage() {
  const health = await getBusinessHealth();

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <Link href="/dashboard" className="mb-6 inline-block text-sm text-muted">
        ‹ Dashboard
      </Link>

      <div className="mb-8 text-center">
        <p className="text-4xl font-semibold tabular-nums text-accent">
          {health.score}
          <span className="text-lg font-normal text-muted">/100</span>
        </p>
        <p className="mt-1 text-sm font-bold uppercase tracking-widest text-accent">{health.band}</p>
        <p className="mt-2 text-sm text-muted">{health.why.join(" · ")}</p>
      </div>

      <p className="mb-2 text-xs uppercase tracking-widest text-muted">How the score is calculated</p>
      <p className="mb-6 text-xs text-muted">
        Five factors, each weighted and scored from your real numbers — never random.
      </p>

      {health.factors.map((factor) => (
        <HealthFactorRow key={factor.name} factor={factor} />
      ))}
    </div>
  );
}
