"use client";

import {
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
  Legend,
} from "recharts";
import { formatEGP } from "@/lib/currency";

export default function TrendLineChart({
  data,
}: {
  data: { month: string; income: number; expense: number; net: number }[];
}) {
  return (
    <ResponsiveContainer width="100%" height={280}>
      <LineChart data={data} margin={{ left: -12, right: 12, top: 8 }}>
        <CartesianGrid stroke="#e6e6e6" vertical={false} />
        <XAxis dataKey="month" tick={{ fontSize: 11, fill: "#767676" }} axisLine={false} tickLine={false} />
        <YAxis tick={{ fontSize: 11, fill: "#767676" }} axisLine={false} tickLine={false} width={0} />
        <Tooltip formatter={(value) => formatEGP(Number(value))} contentStyle={{ fontSize: 12, border: "1px solid #e6e6e6" }} />
        <Legend wrapperStyle={{ fontSize: 12 }} />
        <Line type="monotone" dataKey="income" name="Income" stroke="#1f7a4d" strokeWidth={2} dot={false} />
        <Line type="monotone" dataKey="expense" name="Expense" stroke="#b3401f" strokeWidth={2} dot={false} />
        <Line type="monotone" dataKey="net" name="Net" stroke="#131313" strokeWidth={2} dot={false} />
      </LineChart>
    </ResponsiveContainer>
  );
}
