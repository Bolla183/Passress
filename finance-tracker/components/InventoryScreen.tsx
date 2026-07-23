"use client";

import { useCallback, useEffect, useState } from "react";
import { formatEGP } from "@/lib/currency";
import { dateInputValue } from "@/lib/dates";

type Option = { id: string; name: string };
type Product = { id: string; name: string; type: "RAW_MATERIAL" | "FINISHED_GOOD"; cost: number; price: number };

type StockRow = {
  id: string;
  productName: string;
  productSku: string;
  warehouseName: string;
  quantityOnHand: number;
};

type Movement = {
  id: string;
  type: string;
  date: string;
  productName: string;
  warehouseName: string;
  supplierName: string | null;
  quantity: number;
  unitCost: number;
  memo: string | null;
};

type Tab = "stock" | "purchase" | "sale" | "transform";

export default function InventoryScreen({
  products,
  warehouses,
  suppliers,
  customers,
  revenueAccounts,
  bankAccounts,
}: {
  products: Product[];
  warehouses: Option[];
  suppliers: Option[];
  customers: Option[];
  revenueAccounts: Option[];
  bankAccounts: Option[];
}) {
  const [tab, setTab] = useState<Tab>("stock");
  const [stock, setStock] = useState<StockRow[]>([]);
  const [movements, setMovements] = useState<Movement[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const rawProducts = products.filter((p) => p.type === "RAW_MATERIAL");
  const finishedProducts = products.filter((p) => p.type === "FINISHED_GOOD");

  const [purchaseForm, setPurchaseForm] = useState({
    productId: products[0]?.id ?? "",
    warehouseId: warehouses[0]?.id ?? "",
    supplierId: suppliers[0]?.id ?? "",
    quantity: "",
    unitCost: "",
    date: dateInputValue(new Date()),
    paid: true,
    bankAccountId: bankAccounts[0]?.id ?? "",
    notes: "",
  });

  const [saleForm, setSaleForm] = useState({
    productId: products[0]?.id ?? "",
    warehouseId: warehouses[0]?.id ?? "",
    quantity: "",
    salePrice: "",
    revenueAccountId: revenueAccounts[0]?.id ?? "",
    date: dateInputValue(new Date()),
    paid: true,
    bankAccountId: bankAccounts[0]?.id ?? "",
    customerId: customers[0]?.id ?? "",
    notes: "",
  });

  const [transformForm, setTransformForm] = useState({
    rawProductId: rawProducts[0]?.id ?? "",
    rawWarehouseId: warehouses[0]?.id ?? "",
    rawQuantity: "",
    finishedProductId: finishedProducts[0]?.id ?? "",
    finishedWarehouseId: warehouses[0]?.id ?? "",
    finishedQuantity: "",
    date: dateInputValue(new Date()),
    notes: "",
  });

  const load = useCallback(async () => {
    setLoading(true);
    const [stockRes, movementsRes] = await Promise.all([
      fetch("/api/inventory/stock"),
      fetch("/api/inventory/movements"),
    ]);
    const stockBody = await stockRes.json();
    const movementsBody = await movementsRes.json();
    setStock(stockBody.stock ?? []);
    setMovements(movementsBody.movements ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- fetch-on-mount
    load();
  }, [load]);

  function handleProductChange(productId: string, setter: (id: string) => void, fillCost?: (cost: number, price: number) => void) {
    setter(productId);
    const product = products.find((p) => p.id === productId);
    if (product && fillCost) fillCost(product.cost, product.price);
  }

  async function handlePurchase(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setMessage(null);
    const res = await fetch("/api/inventory/purchase", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(purchaseForm),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error || "Could not save");
      return;
    }
    setMessage("Purchase recorded");
    setPurchaseForm((f) => ({ ...f, quantity: "", unitCost: "", notes: "" }));
    load();
  }

  async function handleSale(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setMessage(null);
    const res = await fetch("/api/inventory/sale", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(saleForm),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error || "Could not save");
      return;
    }
    setMessage("Sale recorded");
    setSaleForm((f) => ({ ...f, quantity: "", salePrice: "", notes: "" }));
    load();
  }

  async function handleTransform(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setMessage(null);
    const res = await fetch("/api/inventory/transform", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(transformForm),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error || "Could not save");
      return;
    }
    setMessage("Manufacturing recorded");
    setTransformForm((f) => ({ ...f, rawQuantity: "", finishedQuantity: "", notes: "" }));
    load();
  }

  const TABS: { id: Tab; label: string }[] = [
    { id: "stock", label: "Stock" },
    { id: "purchase", label: "Purchase" },
    { id: "sale", label: "Sale" },
    { id: "transform", label: "Manufacture" },
  ];

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-6 text-lg tracking-widest uppercase">Inventory</h1>

      <div className="mb-6 flex border border-hairline">
        {TABS.map((t) => (
          <button
            key={t.id}
            onClick={() => {
              setTab(t.id);
              setError(null);
              setMessage(null);
            }}
            className={`flex-1 py-2 text-xs uppercase tracking-widest ${
              tab === t.id ? "bg-ink text-paper" : "text-muted"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {error && <p className="mb-4 text-sm text-expense">{error}</p>}
      {message && <p className="mb-4 text-sm text-income">{message}</p>}

      {tab === "stock" && (
        <div className="mb-8">
          {loading ? (
            <p className="py-6 text-sm text-muted">Loading...</p>
          ) : stock.length === 0 ? (
            <p className="py-6 text-sm text-muted">No stock yet — record a purchase to add some.</p>
          ) : (
            <ul>
              {stock.map((row) => (
                <li key={row.id} className="flex items-center justify-between border-b border-hairline py-3">
                  <div>
                    <p className="text-sm">{row.productName}</p>
                    <p className="text-xs text-muted">
                      {row.productSku} · {row.warehouseName}
                    </p>
                  </div>
                  <p className="text-sm">{row.quantityOnHand}</p>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      {tab === "purchase" && (
        <form onSubmit={handlePurchase} className="mb-8 border border-hairline p-4">
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Product</span>
            <select
              value={purchaseForm.productId}
              onChange={(e) =>
                handleProductChange(e.target.value, (id) => setPurchaseForm({ ...purchaseForm, productId: id }), (cost) =>
                  setPurchaseForm((f) => ({ ...f, unitCost: String(cost) }))
                )
              }
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              {products.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Warehouse</span>
            <select
              value={purchaseForm.warehouseId}
              onChange={(e) => setPurchaseForm({ ...purchaseForm, warehouseId: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              {warehouses.map((w) => (
                <option key={w.id} value={w.id}>
                  {w.name}
                </option>
              ))}
            </select>
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Supplier</span>
            <select
              value={purchaseForm.supplierId}
              onChange={(e) => setPurchaseForm({ ...purchaseForm, supplierId: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              {suppliers.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Quantity</span>
            <input
              type="number"
              min="0"
              step="0.01"
              value={purchaseForm.quantity}
              onChange={(e) => setPurchaseForm({ ...purchaseForm, quantity: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Unit cost (EGP)</span>
            <input
              type="number"
              min="0"
              step="0.01"
              value={purchaseForm.unitCost}
              onChange={(e) => setPurchaseForm({ ...purchaseForm, unitCost: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Date</span>
            <input
              type="date"
              value={purchaseForm.date}
              onChange={(e) => setPurchaseForm({ ...purchaseForm, date: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-3 flex items-center gap-2">
            <input
              type="checkbox"
              checked={purchaseForm.paid}
              onChange={(e) => setPurchaseForm({ ...purchaseForm, paid: e.target.checked })}
            />
            <span className="text-xs uppercase tracking-widest text-muted">Paid immediately</span>
          </label>
          {purchaseForm.paid && (
            <label className="mb-4 block">
              <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Paid from</span>
              <select
                value={purchaseForm.bankAccountId}
                onChange={(e) => setPurchaseForm({ ...purchaseForm, bankAccountId: e.target.value })}
                className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
              >
                {bankAccounts.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.name}
                  </option>
                ))}
              </select>
            </label>
          )}
          {!purchaseForm.paid && (
            <p className="mb-4 text-xs text-muted">
              Will be recorded as an unpaid bill — pay it later from Workflows → Bills.
            </p>
          )}
          <button type="submit" className="bg-ink px-3 py-1.5 text-xs uppercase tracking-widest text-paper">
            Record Purchase
          </button>
        </form>
      )}

      {tab === "sale" && (
        <form onSubmit={handleSale} className="mb-8 border border-hairline p-4">
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Product</span>
            <select
              value={saleForm.productId}
              onChange={(e) =>
                handleProductChange(e.target.value, (id) => setSaleForm({ ...saleForm, productId: id }), (_cost, price) =>
                  setSaleForm((f) => ({ ...f, salePrice: String(price) }))
                )
              }
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              {products.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Warehouse</span>
            <select
              value={saleForm.warehouseId}
              onChange={(e) => setSaleForm({ ...saleForm, warehouseId: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              {warehouses.map((w) => (
                <option key={w.id} value={w.id}>
                  {w.name}
                </option>
              ))}
            </select>
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Revenue category</span>
            <select
              value={saleForm.revenueAccountId}
              onChange={(e) => setSaleForm({ ...saleForm, revenueAccountId: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              {revenueAccounts.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.name}
                </option>
              ))}
            </select>
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Quantity</span>
            <input
              type="number"
              min="0"
              step="0.01"
              value={saleForm.quantity}
              onChange={(e) => setSaleForm({ ...saleForm, quantity: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Sale price, total (EGP)</span>
            <input
              type="number"
              min="0"
              step="0.01"
              value={saleForm.salePrice}
              onChange={(e) => setSaleForm({ ...saleForm, salePrice: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Date</span>
            <input
              type="date"
              value={saleForm.date}
              onChange={(e) => setSaleForm({ ...saleForm, date: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-3 flex items-center gap-2">
            <input
              type="checkbox"
              checked={saleForm.paid}
              onChange={(e) => setSaleForm({ ...saleForm, paid: e.target.checked })}
            />
            <span className="text-xs uppercase tracking-widest text-muted">Paid immediately</span>
          </label>
          {saleForm.paid ? (
            <label className="mb-4 block">
              <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Received into</span>
              <select
                value={saleForm.bankAccountId}
                onChange={(e) => setSaleForm({ ...saleForm, bankAccountId: e.target.value })}
                className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
              >
                {bankAccounts.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.name}
                  </option>
                ))}
              </select>
            </label>
          ) : (
            <label className="mb-4 block">
              <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Customer</span>
              <select
                value={saleForm.customerId}
                onChange={(e) => setSaleForm({ ...saleForm, customerId: e.target.value })}
                className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
              >
                {customers.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
              <p className="mt-1 text-xs text-muted">Tracked as an invoice — collect later from Workflows → Invoices.</p>
            </label>
          )}
          <button type="submit" className="bg-ink px-3 py-1.5 text-xs uppercase tracking-widest text-paper">
            Record Sale
          </button>
        </form>
      )}

      {tab === "transform" && (
        <form onSubmit={handleTransform} className="mb-8 border border-hairline p-4">
          <p className="mb-3 text-xs uppercase tracking-widest text-muted">Consume raw material</p>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Raw material</span>
            <select
              value={transformForm.rawProductId}
              onChange={(e) => setTransformForm({ ...transformForm, rawProductId: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              {rawProducts.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Warehouse</span>
            <select
              value={transformForm.rawWarehouseId}
              onChange={(e) => setTransformForm({ ...transformForm, rawWarehouseId: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              {warehouses.map((w) => (
                <option key={w.id} value={w.id}>
                  {w.name}
                </option>
              ))}
            </select>
          </label>
          <label className="mb-4 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Quantity consumed</span>
            <input
              type="number"
              min="0"
              step="0.01"
              value={transformForm.rawQuantity}
              onChange={(e) => setTransformForm({ ...transformForm, rawQuantity: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>

          <p className="mb-3 text-xs uppercase tracking-widest text-muted">Produce finished good</p>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Finished good</span>
            <select
              value={transformForm.finishedProductId}
              onChange={(e) => setTransformForm({ ...transformForm, finishedProductId: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              {finishedProducts.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Warehouse</span>
            <select
              value={transformForm.finishedWarehouseId}
              onChange={(e) => setTransformForm({ ...transformForm, finishedWarehouseId: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              {warehouses.map((w) => (
                <option key={w.id} value={w.id}>
                  {w.name}
                </option>
              ))}
            </select>
          </label>
          <label className="mb-4 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Quantity produced</span>
            <input
              type="number"
              min="0"
              step="0.01"
              value={transformForm.finishedQuantity}
              onChange={(e) => setTransformForm({ ...transformForm, finishedQuantity: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-4 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Date</span>
            <input
              type="date"
              value={transformForm.date}
              onChange={(e) => setTransformForm({ ...transformForm, date: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>

          {rawProducts.length === 0 || finishedProducts.length === 0 ? (
            <p className="mb-3 text-sm text-muted">
              Needs at least one Raw Material and one Finished Good product in Data → Products.
            </p>
          ) : (
            <button type="submit" className="bg-ink px-3 py-1.5 text-xs uppercase tracking-widest text-paper">
              Record Manufacturing
            </button>
          )}
        </form>
      )}

      <p className="mb-2 text-xs uppercase tracking-widest text-muted">Recent Movements</p>
      {movements.length === 0 ? (
        <p className="py-6 text-sm text-muted">No movements yet.</p>
      ) : (
        <ul>
          {movements.map((m) => (
            <li key={m.id} className="border-b border-hairline py-3">
              <div className="flex items-center justify-between">
                <p className="text-sm">
                  {m.productName} · {m.type}
                </p>
                <p className="text-sm">{m.quantity}</p>
              </div>
              <p className="text-xs text-muted">
                {new Date(m.date).toLocaleDateString("en-GB", { timeZone: "UTC" })} · {m.warehouseName}
                {m.supplierName ? ` · ${m.supplierName}` : ""} · {formatEGP(m.unitCost)}/unit
              </p>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
