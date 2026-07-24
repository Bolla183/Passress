import type { AccountType, NormalBalance } from "../../app/generated/prisma/enums";

export type AccountSeedNode = {
  code: string;
  name: string;
  type: AccountType;
  normalBalance: NormalBalance;
  subtype?: string;
  showInQuickAdd?: boolean;
  children?: AccountSeedNode[];
};

// Used only by the one-time legacy-transaction migration script, which maps
// the founder's original fixed category labels onto specific accounts. Live
// quick-add no longer uses this — it reads whichever accounts currently have
// showInQuickAdd = true, so new categories added via the Chart of Accounts
// screen show up with no code change.
export const QUICK_ADD_INCOME_ACCOUNT_CODES: Record<string, string> = {
  "Shopify Sales": "4100",
  Wholesale: "4200",
  "Other Income": "4900",
};

export const QUICK_ADD_EXPENSE_ACCOUNT_CODES: Record<string, string> = {
  "COGS / Inventory": "5000",
  "Marketing & Ads": "5100",
  "Shipping & Fulfillment": "5200",
  "Software & Subscriptions": "5300",
  "Salaries & Contractors": "5400",
  "Rent & Utilities": "5500",
  "Bank & Payment Fees": "5600",
  Misc: "5900",
};

export const DEFAULT_CASH_ACCOUNT_CODE = "1000";

export const CHART_OF_ACCOUNTS: AccountSeedNode[] = [
  {
    code: "1000-GROUP",
    name: "Assets",
    type: "ASSET",
    normalBalance: "DEBIT",
    children: [
      {
        code: "1000",
        name: "Cash",
        type: "ASSET",
        normalBalance: "DEBIT",
        subtype: "CURRENT_ASSET",
      },
      {
        code: "1010",
        name: "Petty Cash",
        type: "ASSET",
        normalBalance: "DEBIT",
        subtype: "CURRENT_ASSET",
      },
      {
        code: "1020",
        name: "Bank - Current Account",
        type: "ASSET",
        normalBalance: "DEBIT",
        subtype: "CURRENT_ASSET",
      },
      {
        code: "1030",
        name: "Bank - Savings Account",
        type: "ASSET",
        normalBalance: "DEBIT",
        subtype: "CURRENT_ASSET",
      },
      {
        code: "1100",
        name: "Accounts Receivable",
        type: "ASSET",
        normalBalance: "DEBIT",
        subtype: "CURRENT_ASSET",
      },
      {
        code: "1200",
        name: "Inventory - Raw Materials",
        type: "ASSET",
        normalBalance: "DEBIT",
        subtype: "CURRENT_ASSET",
      },
      {
        code: "1210",
        name: "Inventory - Finished Goods",
        type: "ASSET",
        normalBalance: "DEBIT",
        subtype: "CURRENT_ASSET",
      },
      {
        code: "1500",
        name: "Fixed Assets - Equipment",
        type: "ASSET",
        normalBalance: "DEBIT",
        subtype: "FIXED_ASSET",
      },
      {
        code: "1510",
        name: "Fixed Assets - Furniture",
        type: "ASSET",
        normalBalance: "DEBIT",
        subtype: "FIXED_ASSET",
      },
      {
        code: "1590",
        name: "Accumulated Depreciation",
        type: "ASSET",
        normalBalance: "CREDIT",
        subtype: "FIXED_ASSET_CONTRA",
      },
    ],
  },
  {
    code: "2000-GROUP",
    name: "Liabilities",
    type: "LIABILITY",
    normalBalance: "CREDIT",
    children: [
      {
        code: "2000",
        name: "Accounts Payable",
        type: "LIABILITY",
        normalBalance: "CREDIT",
        subtype: "CURRENT_LIABILITY",
      },
      {
        code: "2010",
        name: "Credit Card Payable",
        type: "LIABILITY",
        normalBalance: "CREDIT",
        subtype: "CURRENT_LIABILITY",
      },
      {
        code: "2020",
        name: "Salaries Payable",
        type: "LIABILITY",
        normalBalance: "CREDIT",
        subtype: "CURRENT_LIABILITY",
      },
      {
        code: "2500",
        name: "Business Loan Payable",
        type: "LIABILITY",
        normalBalance: "CREDIT",
        subtype: "LONG_TERM_LIABILITY",
      },
    ],
  },
  {
    code: "3000-GROUP",
    name: "Equity",
    type: "EQUITY",
    normalBalance: "CREDIT",
    children: [
      { code: "3000", name: "Owner's Equity", type: "EQUITY", normalBalance: "CREDIT" },
      { code: "3100", name: "Retained Earnings", type: "EQUITY", normalBalance: "CREDIT" },
    ],
  },
  {
    code: "4000-GROUP",
    name: "Revenue",
    type: "REVENUE",
    normalBalance: "CREDIT",
    children: [
      { code: "4100", name: "Shopify Sales", type: "REVENUE", normalBalance: "CREDIT", showInQuickAdd: true },
      { code: "4200", name: "Wholesale", type: "REVENUE", normalBalance: "CREDIT", showInQuickAdd: true },
      { code: "4900", name: "Other Income", type: "REVENUE", normalBalance: "CREDIT", showInQuickAdd: true },
    ],
  },
  {
    code: "5000-GROUP",
    name: "Expenses",
    type: "EXPENSE",
    normalBalance: "DEBIT",
    children: [
      {
        code: "5000",
        name: "COGS / Inventory",
        type: "EXPENSE",
        normalBalance: "DEBIT",
        showInQuickAdd: true,
        children: [
          { code: "5010", name: "Sample Production", type: "EXPENSE", normalBalance: "DEBIT", showInQuickAdd: true },
          { code: "5020", name: "Fabric", type: "EXPENSE", normalBalance: "DEBIT", showInQuickAdd: true },
        ],
      },
      {
        code: "5100",
        name: "Marketing & Ads",
        type: "EXPENSE",
        normalBalance: "DEBIT",
        showInQuickAdd: true,
        children: [
          { code: "5110", name: "Meta Ads", type: "EXPENSE", normalBalance: "DEBIT" },
          { code: "5120", name: "Google Ads", type: "EXPENSE", normalBalance: "DEBIT" },
          { code: "5130", name: "TikTok Ads", type: "EXPENSE", normalBalance: "DEBIT" },
          { code: "5140", name: "Influencers", type: "EXPENSE", normalBalance: "DEBIT" },
          { code: "5150", name: "Sample Giveaways", type: "EXPENSE", normalBalance: "DEBIT", showInQuickAdd: true },
        ],
      },
      {
        code: "5200",
        name: "Shipping & Fulfillment",
        type: "EXPENSE",
        normalBalance: "DEBIT",
        showInQuickAdd: true,
        children: [
          { code: "5210", name: "Delivery", type: "EXPENSE", normalBalance: "DEBIT" },
          { code: "5220", name: "Packaging", type: "EXPENSE", normalBalance: "DEBIT" },
        ],
      },
      {
        code: "5300",
        name: "Software & Subscriptions",
        type: "EXPENSE",
        normalBalance: "DEBIT",
        showInQuickAdd: true,
        children: [
          { code: "5310", name: "Shopify Subscription", type: "EXPENSE", normalBalance: "DEBIT" },
          { code: "5320", name: "ChatGPT", type: "EXPENSE", normalBalance: "DEBIT" },
          { code: "5330", name: "Canva", type: "EXPENSE", normalBalance: "DEBIT" },
          { code: "5340", name: "Adobe", type: "EXPENSE", normalBalance: "DEBIT" },
        ],
      },
      {
        code: "5400",
        name: "Salaries & Contractors",
        type: "EXPENSE",
        normalBalance: "DEBIT",
        showInQuickAdd: true,
        children: [
          { code: "5410", name: "Salaries", type: "EXPENSE", normalBalance: "DEBIT" },
          { code: "5420", name: "Bonuses", type: "EXPENSE", normalBalance: "DEBIT" },
          { code: "5430", name: "Overtime", type: "EXPENSE", normalBalance: "DEBIT" },
        ],
      },
      {
        code: "5500",
        name: "Rent & Utilities",
        type: "EXPENSE",
        normalBalance: "DEBIT",
        showInQuickAdd: true,
        children: [
          { code: "5510", name: "Rent", type: "EXPENSE", normalBalance: "DEBIT" },
          { code: "5520", name: "Utilities", type: "EXPENSE", normalBalance: "DEBIT" },
          { code: "5530", name: "Internet", type: "EXPENSE", normalBalance: "DEBIT" },
        ],
      },
      {
        code: "5600",
        name: "Bank & Payment Fees",
        type: "EXPENSE",
        normalBalance: "DEBIT",
        showInQuickAdd: true,
        children: [
          { code: "5610", name: "Bank Fees", type: "EXPENSE", normalBalance: "DEBIT" },
          { code: "5620", name: "Interest Expense", type: "EXPENSE", normalBalance: "DEBIT" },
        ],
      },
      { code: "5900", name: "Misc", type: "EXPENSE", normalBalance: "DEBIT", showInQuickAdd: true },
    ],
  },
];
