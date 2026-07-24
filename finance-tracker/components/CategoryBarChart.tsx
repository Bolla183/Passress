"use client";

import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { formatEGP } from "@/lib/currency";

export default function CategoryBarChart({
  data,
}: {
  data: { category: string; amount: number }[];
}) {
  if (data.length === 0) {
    return <p className="py-6 text-sm text-muted">No expenses this month.</p>;
  }

  return (
    <ResponsiveContainer width="100%" height={Math.max(200, data.length * 44)}>
      <BarChart data={data} layout="vertical" margin={{ left: 8, right: 24 }}>
        <CartesianGrid horizontal={false} stroke="#e6e6e6" />
        <XAxis type="number" hide />
        <YAxis
          type="category"
          dataKey="category"
          width={150}
          tick={{ fontSize: 12, fill: "#767676" }}
          axisLine={false}
          tickLine={false}
        />
        <Tooltip
          formatter={(value) => formatEGP(Number(value))}
          contentStyle={{ fontSize: 12, border: "1px solid #e6e6e6", borderRadius: 8 }}
        />
        <Bar dataKey="amount" fill="#131313" radius={[0, 6, 6, 0]} maxBarSize={18} />
      </BarChart>
    </ResponsiveContainer>
  );
}
