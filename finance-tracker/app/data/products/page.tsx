import { prisma } from "@/lib/prisma";
import { DEFAULT_COMPANY_ID } from "@/lib/accounting/company";
import MasterDataScreen from "@/components/MasterDataScreen";
import type { FieldConfig } from "@/components/MasterDataScreen";

export const dynamic = "force-dynamic";

const PRODUCT_TYPES = [
  { value: "RAW_MATERIAL", label: "Raw Material" },
  { value: "FINISHED_GOOD", label: "Finished Good" },
];

export default async function ProductsPage() {
  const [categories, brands, collections, inventoryAccounts] = await Promise.all([
    prisma.productCategory.findMany({ where: { companyId: DEFAULT_COMPANY_ID, isActive: true }, orderBy: { name: "asc" } }),
    prisma.brand.findMany({ where: { companyId: DEFAULT_COMPANY_ID, isActive: true }, orderBy: { name: "asc" } }),
    prisma.collection.findMany({ where: { companyId: DEFAULT_COMPANY_ID, isActive: true }, orderBy: { name: "asc" } }),
    prisma.account.findMany({
      where: { companyId: DEFAULT_COMPANY_ID, isActive: true, subtype: "CURRENT_ASSET", name: { contains: "Inventory" } },
      orderBy: { code: "asc" },
    }),
  ]);

  const fields: FieldConfig[] = [
    { name: "name", label: "Name", type: "text", required: true },
    { name: "sku", label: "SKU", type: "text", required: true },
    { name: "type", label: "Type", type: "select", required: true, options: PRODUCT_TYPES },
    { name: "cost", label: "Cost (EGP)", type: "number" },
    { name: "price", label: "Price (EGP)", type: "number" },
    {
      name: "productCategoryId",
      label: "Category",
      type: "select",
      options: categories.map((c) => ({ value: c.id, label: c.name })),
    },
    {
      name: "brandId",
      label: "Brand",
      type: "select",
      options: brands.map((b) => ({ value: b.id, label: b.name })),
    },
    {
      name: "collectionId",
      label: "Collection",
      type: "select",
      options: collections.map((c) => ({ value: c.id, label: c.name })),
    },
    {
      name: "inventoryAccountId",
      label: "Inventory GL account",
      type: "select",
      options: inventoryAccounts.map((a) => ({ value: a.id, label: `${a.code} · ${a.name}` })),
    },
    { name: "isActive", label: "Active", type: "checkbox" },
  ];

  return <MasterDataScreen entity="products" title="Products" fields={fields} />;
}
