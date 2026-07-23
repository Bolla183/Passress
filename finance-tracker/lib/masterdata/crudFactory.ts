/* eslint-disable @typescript-eslint/no-explicit-any */
import { DEFAULT_COMPANY_ID } from "../accounting/company";

type PaginationArgs = {
  page?: number;
  pageSize?: number;
  search?: string;
  activeOnly?: boolean;
};

// Minimal shape every Prisma model delegate satisfies — enough to build one
// reusable CRUD service instead of hand-writing the same list/get/create/
// update/remove logic 18 times. `any` args here is intentional: Prisma's
// generated per-model arg types are structurally incompatible with each
// other, and this factory's job is precisely to erase those differences.
type Delegate = {
  findMany: (args: any) => Promise<unknown[]>;
  count: (args: any) => Promise<number>;
  findUnique: (args: any) => Promise<unknown>;
  create: (args: any) => Promise<unknown>;
  update: (args: any) => Promise<unknown>;
  delete: (args: any) => Promise<unknown>;
};

export function createCrudService(delegate: Delegate, searchField?: string) {
  async function list(
    { page = 1, pageSize = 25, search, activeOnly }: PaginationArgs = {},
    companyId: string = DEFAULT_COMPANY_ID
  ) {
    const where: Record<string, unknown> = { companyId };
    if (search && searchField) {
      where[searchField] = { contains: search, mode: "insensitive" };
    }
    if (activeOnly) {
      where.isActive = true;
    }

    const orderBy = searchField ? { [searchField]: "asc" } : { createdAt: "desc" };

    const [items, total] = await Promise.all([
      delegate.findMany({ where, orderBy, skip: (page - 1) * pageSize, take: pageSize }),
      delegate.count({ where }),
    ]);

    return { items, total, page, pageSize };
  }

  async function get(id: string) {
    return delegate.findUnique({ where: { id } });
  }

  async function create(
    data: Record<string, unknown>,
    createdBy?: string,
    companyId: string = DEFAULT_COMPANY_ID
  ) {
    return delegate.create({ data: { ...data, companyId, createdBy } });
  }

  async function update(id: string, data: Record<string, unknown>, updatedBy?: string) {
    return delegate.update({ where: { id }, data: { ...data, updatedBy } });
  }

  async function remove(id: string) {
    return delegate.delete({ where: { id } });
  }

  return { list, get, create, update, remove };
}
