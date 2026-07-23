import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const productCategoryService = createCrudService(prisma.productCategory, "name");
