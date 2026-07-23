import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const warehouseService = createCrudService(prisma.warehouse, "name");
