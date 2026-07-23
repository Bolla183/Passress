import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const productService = createCrudService(prisma.product, "name");
