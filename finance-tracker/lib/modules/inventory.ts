import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID } from "../accounting/company";
import { postJournalEntry, getAccountByCode } from "../accounting/ledger";
import { recordBill, recordBillPayment } from "./bills";

const COGS_ACCOUNT_CODE = "5000";
const RAW_MATERIAL_INVENTORY_CODE = "1200";
const FINISHED_GOOD_INVENTORY_CODE = "1210";

async function resolveInventoryAccountId(
  product: { inventoryAccountId: string | null; type: "RAW_MATERIAL" | "FINISHED_GOOD" },
  companyId: string
): Promise<string> {
  if (product.inventoryAccountId) return product.inventoryAccountId;
  const code = product.type === "RAW_MATERIAL" ? RAW_MATERIAL_INVENTORY_CODE : FINISHED_GOOD_INVENTORY_CODE;
  const account = await getAccountByCode(code, companyId);
  return account.id;
}

async function adjustStock(
  productId: string,
  warehouseId: string,
  delta: number,
  companyId: string
) {
  const existing = await prisma.inventoryItem.findUnique({
    where: { productId_warehouseId: { productId, warehouseId } },
  });

  if (existing) {
    return prisma.inventoryItem.update({
      where: { productId_warehouseId: { productId, warehouseId } },
      data: { quantityOnHand: Number(existing.quantityOnHand) + delta },
    });
  }

  return prisma.inventoryItem.create({
    data: { companyId, productId, warehouseId, quantityOnHand: delta },
  });
}

export async function getStockLevels(companyId = DEFAULT_COMPANY_ID) {
  const items = await prisma.inventoryItem.findMany({
    where: { companyId },
    include: { product: true, warehouse: true },
    orderBy: { product: { name: "asc" } },
  });
  return items.map((i) => ({
    id: i.id,
    productName: i.product.name,
    productSku: i.product.sku,
    warehouseName: i.warehouse.name,
    quantityOnHand: Number(i.quantityOnHand),
  }));
}

export async function listInventoryMovements(companyId = DEFAULT_COMPANY_ID) {
  const movements = await prisma.inventoryMovement.findMany({
    where: { companyId },
    include: { product: true, warehouse: true, supplier: true },
    orderBy: { date: "desc" },
    take: 50,
  });
  return movements.map((m) => ({
    id: m.id,
    type: m.type,
    date: m.date,
    productName: m.product.name,
    warehouseName: m.warehouse.name,
    supplierName: m.supplier?.name ?? null,
    quantity: Number(m.quantity),
    unitCost: Number(m.unitCost),
    memo: m.memo,
  }));
}

// Purchases are recorded as a Bill (Debit Inventory / Credit Accounts
// Payable) so every purchase — paid or not — shows up in the existing
// Bills screen for payment tracking, rather than needing a second ledger.
export async function recordPurchase(input: {
  productId: string;
  warehouseId: string;
  supplierId: string;
  quantity: number;
  unitCost: number;
  date: Date;
  settlement: { type: "CASH"; bankAccountId: string } | { type: "CREDIT" };
  notes?: string;
  companyId?: string;
}) {
  const companyId = input.companyId ?? DEFAULT_COMPANY_ID;
  const product = await prisma.product.findUnique({ where: { id: input.productId } });
  if (!product) throw new Error("Product not found");

  const inventoryAccountId = await resolveInventoryAccountId(product, companyId);
  const amount = input.quantity * input.unitCost;

  const bill = await recordBill({
    companyId,
    supplierId: input.supplierId,
    accountId: inventoryAccountId,
    amount,
    billDate: input.date,
    notes: input.notes ?? `Purchase: ${product.name}`,
  });

  if (input.settlement.type === "CASH") {
    await recordBillPayment({
      companyId,
      billId: bill.id,
      amount,
      date: input.date,
      bankAccountId: input.settlement.bankAccountId,
    });
  }

  await adjustStock(input.productId, input.warehouseId, input.quantity, companyId);

  return prisma.inventoryMovement.create({
    data: {
      companyId,
      productId: input.productId,
      warehouseId: input.warehouseId,
      supplierId: input.supplierId,
      type: "PURCHASE",
      quantity: input.quantity,
      unitCost: input.unitCost,
      journalEntryId: bill.journalEntryId,
      date: input.date,
      memo: input.notes,
    },
  });
}

// A sale posts one balanced four-line entry: Debit COGS / Credit Inventory
// at cost, and Debit Cash-or-AR / Credit Revenue at the sale price. Credit
// sales also create an Invoice row (referencing the same journal entry) so
// collection is tracked through the existing Invoices screen.
export async function recordSale(input: {
  productId: string;
  warehouseId: string;
  quantity: number;
  salePrice: number;
  revenueAccountId: string;
  date: Date;
  settlement: { type: "CASH"; bankAccountId: string } | { type: "CREDIT"; customerId: string };
  notes?: string;
  companyId?: string;
}) {
  const companyId = input.companyId ?? DEFAULT_COMPANY_ID;
  const product = await prisma.product.findUnique({ where: { id: input.productId } });
  if (!product) throw new Error("Product not found");

  const stock = await prisma.inventoryItem.findUnique({
    where: { productId_warehouseId: { productId: input.productId, warehouseId: input.warehouseId } },
  });
  const available = stock ? Number(stock.quantityOnHand) : 0;
  if (input.quantity > available + 0.0005) {
    throw new Error(`Insufficient stock: only ${available} on hand`);
  }

  const inventoryAccountId = await resolveInventoryAccountId(product, companyId);
  const cogsAccount = await getAccountByCode(COGS_ACCOUNT_CODE, companyId);
  const cost = input.quantity * Number(product.cost);

  const settlementAccountId =
    input.settlement.type === "CASH"
      ? (await prisma.bankAccount.findUnique({ where: { id: input.settlement.bankAccountId } }))?.glAccountId
      : (await getAccountByCode("1100", companyId)).id; // Accounts Receivable

  if (!settlementAccountId) throw new Error("Bank account not found");

  const entry = await postJournalEntry({
    companyId,
    date: input.date,
    memo: input.notes ?? `Sale: ${product.name}`,
    source: "MANUAL",
    lines: [
      { accountId: cogsAccount.id, debit: cost, productId: input.productId },
      { accountId: inventoryAccountId, credit: cost, productId: input.productId },
      { accountId: settlementAccountId, debit: input.salePrice, productId: input.productId },
      { accountId: input.revenueAccountId, credit: input.salePrice, productId: input.productId },
    ],
  });

  await adjustStock(input.productId, input.warehouseId, -input.quantity, companyId);

  if (input.settlement.type === "CREDIT") {
    await prisma.invoice.create({
      data: {
        companyId,
        customerId: input.settlement.customerId,
        accountId: input.revenueAccountId,
        amount: input.salePrice,
        invoiceDate: input.date,
        notes: input.notes ?? `Sale: ${product.name}`,
        journalEntryId: entry.id,
      },
    });
  }

  return prisma.inventoryMovement.create({
    data: {
      companyId,
      productId: input.productId,
      warehouseId: input.warehouseId,
      type: "SALE",
      quantity: input.quantity,
      unitCost: Number(product.cost),
      journalEntryId: entry.id,
      date: input.date,
      memo: input.notes,
    },
  });
}

// Moves value from raw materials into finished goods at the raw material's
// cost — a simplified costing model (no separate labor/overhead accounts)
// appropriate for a small production run today, extendable later.
export async function recordTransform(input: {
  rawProductId: string;
  rawWarehouseId: string;
  rawQuantity: number;
  finishedProductId: string;
  finishedWarehouseId: string;
  finishedQuantity: number;
  date: Date;
  notes?: string;
  companyId?: string;
}) {
  const companyId = input.companyId ?? DEFAULT_COMPANY_ID;
  const [rawProduct, finishedProduct] = await Promise.all([
    prisma.product.findUnique({ where: { id: input.rawProductId } }),
    prisma.product.findUnique({ where: { id: input.finishedProductId } }),
  ]);
  if (!rawProduct || !finishedProduct) throw new Error("Product not found");

  const stock = await prisma.inventoryItem.findUnique({
    where: { productId_warehouseId: { productId: input.rawProductId, warehouseId: input.rawWarehouseId } },
  });
  const available = stock ? Number(stock.quantityOnHand) : 0;
  if (input.rawQuantity > available + 0.0005) {
    throw new Error(`Insufficient raw material stock: only ${available} on hand`);
  }

  const [rawAccountId, finishedAccountId] = await Promise.all([
    resolveInventoryAccountId(rawProduct, companyId),
    resolveInventoryAccountId(finishedProduct, companyId),
  ]);

  const costMoved = input.rawQuantity * Number(rawProduct.cost);

  const entry = await postJournalEntry({
    companyId,
    date: input.date,
    memo: input.notes ?? `Manufacture: ${finishedProduct.name}`,
    source: "MANUAL",
    lines: [
      { accountId: finishedAccountId, debit: costMoved, productId: input.finishedProductId },
      { accountId: rawAccountId, credit: costMoved, productId: input.rawProductId },
    ],
  });

  await adjustStock(input.rawProductId, input.rawWarehouseId, -input.rawQuantity, companyId);
  await adjustStock(input.finishedProductId, input.finishedWarehouseId, input.finishedQuantity, companyId);

  await prisma.inventoryMovement.create({
    data: {
      companyId,
      productId: input.rawProductId,
      warehouseId: input.rawWarehouseId,
      type: "TRANSFORM",
      quantity: input.rawQuantity,
      unitCost: Number(rawProduct.cost),
      journalEntryId: entry.id,
      date: input.date,
      memo: input.notes ?? `Consumed into ${finishedProduct.name}`,
    },
  });

  return prisma.inventoryMovement.create({
    data: {
      companyId,
      productId: input.finishedProductId,
      warehouseId: input.finishedWarehouseId,
      type: "TRANSFORM",
      quantity: input.finishedQuantity,
      unitCost: input.finishedQuantity > 0 ? costMoved / input.finishedQuantity : 0,
      journalEntryId: entry.id,
      date: input.date,
      memo: input.notes ?? `Produced from ${rawProduct.name}`,
    },
  });
}
