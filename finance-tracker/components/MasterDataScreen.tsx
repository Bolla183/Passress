"use client";

import { useCallback, useEffect, useState } from "react";

export type FieldConfig = {
  name: string;
  label: string;
  type: "text" | "email" | "tel" | "number" | "select" | "checkbox" | "date";
  required?: boolean;
  options?: { value: string; label: string }[];
};

type Item = Record<string, unknown> & {
  id: string;
  isActive?: boolean;
  createdAt?: string;
  updatedAt?: string;
  createdBy?: string | null;
  updatedBy?: string | null;
};

function displayLabel(item: Item, fields: FieldConfig[]): string {
  const primary = fields[0];
  const value = item[primary.name];
  if (primary.type === "select") {
    return primary.options?.find((o) => o.value === value)?.label ?? String(value ?? "");
  }
  return String(value ?? "");
}

function emptyForm(fields: FieldConfig[]): Record<string, string | boolean> {
  const form: Record<string, string | boolean> = {};
  for (const field of fields) {
    form[field.name] = field.type === "checkbox" ? true : "";
  }
  return form;
}

export default function MasterDataScreen({
  entity,
  title,
  fields,
}: {
  entity: string;
  title: string;
  fields: FieldConfig[];
}) {
  const [items, setItems] = useState<Item[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [activeOnly, setActiveOnly] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState<Record<string, string | boolean>>(emptyForm(fields));
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    const params = new URLSearchParams();
    if (search) params.set("search", search);
    if (activeOnly) params.set("activeOnly", "true");
    const res = await fetch(`/api/masterdata/${entity}?${params.toString()}`);
    const body = await res.json();
    setItems(body.items ?? []);
    setLoading(false);
  }, [entity, search, activeOnly]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- fetch-on-mount/filter-change
    load();
  }, [load]);

  function startAdd() {
    setEditingId(null);
    setForm(emptyForm(fields));
    setShowForm(true);
    setError(null);
  }

  function startEdit(item: Item) {
    const next: Record<string, string | boolean> = {};
    for (const field of fields) {
      const value = item[field.name];
      next[field.name] = field.type === "checkbox" ? Boolean(value) : String(value ?? "");
    }
    setEditingId(item.id);
    setForm(next);
    setShowForm(true);
    setError(null);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    const payload: Record<string, unknown> = {};
    for (const field of fields) {
      const raw = form[field.name];
      if (field.type === "number") payload[field.name] = raw === "" ? undefined : Number(raw);
      else if (field.type === "checkbox") payload[field.name] = raw;
      else payload[field.name] = raw === "" ? undefined : raw;
    }

    const res = editingId
      ? await fetch(`/api/masterdata/${entity}/${editingId}`, {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        })
      : await fetch(`/api/masterdata/${entity}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });

    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error || "Could not save");
      return;
    }

    setShowForm(false);
    load();
  }

  async function handleDelete(id: string) {
    if (!confirm("Delete this record?")) return;
    await fetch(`/api/masterdata/${entity}/${id}`, { method: "DELETE" });
    load();
  }

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-lg tracking-widest uppercase">{title}</h1>
        <button
          onClick={startAdd}
          className="bg-ink px-3 py-1.5 text-xs uppercase tracking-widest text-paper"
        >
          Add
        </button>
      </div>

      <div className="mb-4 flex items-center gap-3">
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search"
          className="flex-1 border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
        />
        <label className="flex items-center gap-1.5 text-xs uppercase tracking-widest text-muted">
          <input
            type="checkbox"
            checked={activeOnly}
            onChange={(e) => setActiveOnly(e.target.checked)}
          />
          Active only
        </label>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} className="mb-6 border border-hairline p-4">
          {fields.map((field) => (
            <label key={field.name} className="mb-3 block">
              <span className="mb-1 block text-xs uppercase tracking-widest text-muted">
                {field.label}
                {field.required ? " *" : ""}
              </span>
              {field.type === "select" ? (
                <select
                  value={String(form[field.name] ?? "")}
                  required={field.required}
                  onChange={(e) => setForm({ ...form, [field.name]: e.target.value })}
                  className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
                >
                  {field.required ? (
                    <option value="" disabled>
                      Select...
                    </option>
                  ) : (
                    <option value="">None</option>
                  )}
                  {field.options?.map((opt) => (
                    <option key={opt.value} value={opt.value}>
                      {opt.label}
                    </option>
                  ))}
                </select>
              ) : field.type === "checkbox" ? (
                <input
                  type="checkbox"
                  checked={Boolean(form[field.name])}
                  onChange={(e) => setForm({ ...form, [field.name]: e.target.checked })}
                />
              ) : (
                <input
                  type={field.type}
                  value={String(form[field.name] ?? "")}
                  required={field.required}
                  onChange={(e) => setForm({ ...form, [field.name]: e.target.value })}
                  className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
                />
              )}
            </label>
          ))}

          {error && <p className="mb-3 text-sm text-expense">{error}</p>}

          <div className="flex gap-3">
            <button type="submit" className="bg-ink px-3 py-1.5 text-xs uppercase tracking-widest text-paper">
              Save
            </button>
            <button
              type="button"
              onClick={() => setShowForm(false)}
              className="px-3 py-1.5 text-xs uppercase tracking-widest text-muted"
            >
              Cancel
            </button>
          </div>
        </form>
      )}

      {loading ? (
        <p className="py-6 text-sm text-muted">Loading...</p>
      ) : items.length === 0 ? (
        <p className="py-6 text-sm text-muted">No records yet.</p>
      ) : (
        <ul>
          {items.map((item) => (
            <li key={item.id} className="border-b border-hairline py-3">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm">
                    {displayLabel(item, fields)}
                    {item.isActive === false && (
                      <span className="ml-2 text-xs uppercase text-muted">Inactive</span>
                    )}
                  </p>
                  {item.createdAt && (
                    <p className="text-xs text-muted">
                      Added {new Date(item.createdAt).toLocaleDateString("en-GB")}
                      {item.updatedAt && item.updatedAt !== item.createdAt
                        ? ` · Updated ${new Date(item.updatedAt).toLocaleDateString("en-GB")}`
                        : ""}
                    </p>
                  )}
                </div>
                <div className="flex items-center gap-3">
                  <button
                    onClick={() => startEdit(item)}
                    className="text-xs uppercase text-muted underline"
                  >
                    Edit
                  </button>
                  <button
                    onClick={() => handleDelete(item.id)}
                    className="text-xs uppercase text-muted underline"
                  >
                    Delete
                  </button>
                </div>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
