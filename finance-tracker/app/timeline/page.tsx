import { getRecentActivity } from "@/lib/accounting/activityFeed";
import TimelineScreen from "@/components/TimelineScreen";

export const dynamic = "force-dynamic";

export default async function TimelinePage() {
  const items = await getRecentActivity(60);

  return (
    <TimelineScreen
      items={items.map((item) => ({ ...item, date: item.date.toISOString() }))}
    />
  );
}
