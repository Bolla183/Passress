import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const brandService = createCrudService(prisma.brand, "name");
