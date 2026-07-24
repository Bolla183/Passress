"use client";

import { Area, AreaChart, CartesianGrid, Legend, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { formatEGP } from "@/lib/currency";

export default function PerformanceAreaChart({
  data,
}: {
  data: { month: string; income: number; expense: number; net: number }[];
}) {
  return (
    <ResponsiveContainer width="100%" height={240}>
      <AreaChart data={data} margin={{ left: -12, right: 12, top: 8 }}>
        <defs>
          <linearGradient id="incomeGradient" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="#1f7a4d" stopOpacity={0.35} />
            <stop offset="95%" stopColor="#1f7a4d" stopOpacity={0} />
          </linearGradient>
          <linearGradient id="expenseGradient" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="#b3401f" stopOpacity={0.3} />
            <stop offset="95%" stopColor="#b3401f" stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid stroke="#e6e6e6" vertical={false} />
        <XAxis dataKey="month" tick={{ fontSize: 11, fill: "#767676" }} axisLine={false} tickLine={false} />
        <YAxis tick={{ fontSize: 11, fill: "#767676" }} axisLine={false} tickLine={false} width={0} />
        <Tooltip
          formatter={(value) => formatEGP(Number(value))}
          contentStyle={{ fontSize: 12, border: "1px solid #e6e6e6", borderRadius: 8 }}
        />
        <Legend wrapperStyle={{ fontSize: 12 }} />
        <Area type="monotone" dataKey="income" name="Revenue" stroke="#1f7a4d" strokeWidth={2} fill="url(#incomeGradient)" />
        <Area type="monotone" dataKey="expense" name="Expense" stroke="#b3401f" strokeWidth={2} fill="url(#expenseGradient)" />
      </AreaChart>
    </ResponsiveContainer>
  );
}
