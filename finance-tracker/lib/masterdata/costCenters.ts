import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const costCenterService = createCrudService(prisma.costCenter, "name");
