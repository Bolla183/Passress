import MasterDataScreen from "@/components/MasterDataScreen";
import type { FieldConfig } from "@/components/MasterDataScreen";

const fields: FieldConfig[] = [
  { name: "name", label: "Name", type: "text", required: true },
  { name: "contactName", label: "Contact name", type: "text" },
  { name: "email", label: "Email", type: "email" },
  { name: "phone", label: "Phone", type: "tel" },
  { name: "address", label: "Address", type: "text" },
  { name: "isActive", label: "Active", type: "checkbox" },
];

export default function SuppliersPage() {
  return <MasterDataScreen entity="suppliers" title="Suppliers" fields={fields} />;
}
