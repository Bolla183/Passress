// Egypt (Africa/Cairo) does not observe daylight saving time.
const CAIRO_OFFSET_MS = 2 * 60 * 60 * 1000;

function cairoShifted(date: Date): Date {
  return new Date(date.getTime() + CAIRO_OFFSET_MS);
}

export function startOfCairoDay(date: Date): Date {
  const shifted = cairoShifted(date);
  const utcMidnight = Date.UTC(
    shifted.getUTCFullYear(),
    shifted.getUTCMonth(),
    shifted.getUTCDate()
  );
  return new Date(utcMidnight - CAIRO_OFFSET_MS);
}

export function endOfCairoDay(date: Date): Date {
  return new Date(startOfCairoDay(date).getTime() + 24 * 60 * 60 * 1000);
}

export function startOfCairoMonth(date: Date): Date {
  const shifted = cairoShifted(date);
  const utcMonthStart = Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth(), 1);
  return new Date(utcMonthStart - CAIRO_OFFSET_MS);
}

export function endOfCairoMonth(date: Date): Date {
  const start = startOfCairoMonth(date);
  const shifted = cairoShifted(start);
  const nextMonthStart = Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth() + 1, 1);
  return new Date(nextMonthStart - CAIRO_OFFSET_MS);
}

export function addMonths(date: Date, months: number): Date {
  const shifted = cairoShifted(date);
  const utc = Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth() + months, 1);
  return new Date(utc - CAIRO_OFFSET_MS);
}

export function startOfCairoQuarter(date: Date): Date {
  const shifted = cairoShifted(date);
  const quarterStartMonth = Math.floor(shifted.getUTCMonth() / 3) * 3;
  const utc = Date.UTC(shifted.getUTCFullYear(), quarterStartMonth, 1);
  return new Date(utc - CAIRO_OFFSET_MS);
}

export function startOfCairoYear(date: Date): Date {
  const shifted = cairoShifted(date);
  const utc = Date.UTC(shifted.getUTCFullYear(), 0, 1);
  return new Date(utc - CAIRO_OFFSET_MS);
}

export function quarterLabel(date: Date): string {
  const shifted = cairoShifted(date);
  const quarter = Math.floor(shifted.getUTCMonth() / 3) + 1;
  return `Q${quarter} ${shifted.getUTCFullYear()}`;
}

export function monthLabel(date: Date): string {
  const shifted = cairoShifted(date);
  return shifted.toLocaleDateString("en-US", { month: "short", year: "numeric", timeZone: "UTC" });
}

export function dateInputValue(date: Date): string {
  const shifted = cairoShifted(date);
  const y = shifted.getUTCFullYear();
  const m = String(shifted.getUTCMonth() + 1).padStart(2, "0");
  const d = String(shifted.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export function parseDateInputValue(value: string): Date {
  return new Date(`${value}T00:00:00Z`);
}

const WEEKDAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MONTH_NAMES = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

// "Today" / "Yesterday" / "Mon, 21 Jul" for Timeline's day-grouped feed.
// Built from fixed name arrays rather than toLocaleDateString -- Node's
// server-side ICU and the browser's client-side ICU can format the same
// locale/options pair with different punctuation (e.g. comma placement),
// which produces a hydration mismatch since this runs in a client component.
export function dayLabel(date: Date, now: Date = new Date()): string {
  const dayMs = 24 * 60 * 60 * 1000;
  const diffDays = Math.round((startOfCairoDay(now).getTime() - startOfCairoDay(date).getTime()) / dayMs);
  if (diffDays === 0) return "Today";
  if (diffDays === 1) return "Yesterday";
  const shifted = cairoShifted(date);
  const weekday = WEEKDAY_NAMES[shifted.getUTCDay()];
  const day = shifted.getUTCDate();
  const month = MONTH_NAMES[shifted.getUTCMonth()];
  return `${weekday}, ${day} ${month}`;
}
