export function formatEGP(amount: number): string {
  const rounded = Math.round(amount);
  return `${rounded.toLocaleString("en-US")} EGP`;
}
