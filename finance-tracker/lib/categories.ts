export const INCOME_CATEGORIES = [
  "Shopify Sales",
  "Wholesale",
  "Other Income",
] as const;

export const EXPENSE_CATEGORIES = [
  "COGS / Inventory",
  "Marketing & Ads",
  "Shipping & Fulfillment",
  "Software & Subscriptions",
  "Salaries & Contractors",
  "Rent & Utilities",
  "Bank & Payment Fees",
  "Misc",
] as const;

export function categoriesFor(type: "INCOME" | "EXPENSE"): readonly string[] {
  return type === "INCOME" ? INCOME_CATEGORIES : EXPENSE_CATEGORIES;
}
