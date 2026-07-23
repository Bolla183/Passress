import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const supplierService = createCrudService(prisma.supplier, "name");
