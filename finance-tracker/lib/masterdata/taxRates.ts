import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const taxRateService = createCrudService(prisma.taxRate, "name");
