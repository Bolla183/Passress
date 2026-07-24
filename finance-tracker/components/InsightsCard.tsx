export default function InsightsCard({ insights }: { insights: string[] }) {
  if (insights.length === 0) return null;

  return (
    <div className="mb-6">
      <p className="mb-2 text-xs uppercase tracking-widest text-muted">Dashboard Insights</p>
      <div className="flex flex-col gap-2">
        {insights.map((text) => (
          <div key={text} className="rounded-xl bg-accent-bg px-4 py-3 text-sm text-ink">
            {text}
          </div>
        ))}
      </div>
    </div>
  );
}
