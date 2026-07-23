import { accountService } from "./accounts";
import { employeeService } from "./employees";
import { supplierService } from "./suppliers";
import { customerService } from "./customers";
import { productService } from "./products";
import { productCategoryService } from "./productCategories";
import { brandService } from "./brands";
import { collectionService } from "./collections";
import { warehouseService } from "./warehouses";
import { locationService } from "./locations";
import { departmentService } from "./departments";
import { costCenterService } from "./costCenters";
import { bankAccountService } from "./bankAccounts";
import { paymentMethodService } from "./paymentMethods";
import { loanService } from "./loans";
import { fixedAssetService } from "./fixedAssets";
import { budgetService } from "./budgets";
import { taxRateService } from "./taxRates";

// Every master-data entity's service, keyed by URL slug, so a single
// generic API route and a single generic screen component can serve all
// 18 entities instead of one-off routes/pages per entity.
export const MASTER_DATA_SERVICES = {
  accounts: accountService,
  employees: employeeService,
  suppliers: supplierService,
  customers: customerService,
  products: productService,
  "product-categories": productCategoryService,
  brands: brandService,
  collections: collectionService,
  warehouses: warehouseService,
  locations: locationService,
  departments: departmentService,
  "cost-centers": costCenterService,
  "bank-accounts": bankAccountService,
  "payment-methods": paymentMethodService,
  loans: loanService,
  "fixed-assets": fixedAssetService,
  budgets: budgetService,
  "tax-rates": taxRateService,
} as const;

export type MasterDataEntity = keyof typeof MASTER_DATA_SERVICES;

export function isMasterDataEntity(value: string): value is MasterDataEntity {
  return value in MASTER_DATA_SERVICES;
}
