import MasterDataScreen from "@/components/MasterDataScreen";
import type { FieldConfig } from "@/components/MasterDataScreen";

const fields: FieldConfig[] = [
  { name: "name", label: "Name", type: "text", required: true },
  { name: "email", label: "Email", type: "email" },
  { name: "phone", label: "Phone", type: "tel" },
  { name: "address", label: "Address", type: "text" },
  { name: "isActive", label: "Active", type: "checkbox" },
];

export default function CustomersPage() {
  return <MasterDataScreen entity="customers" title="Customers" fields={fields} />;
}
