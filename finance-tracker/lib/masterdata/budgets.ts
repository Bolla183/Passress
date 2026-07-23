import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const budgetService = createCrudService(prisma.budget);
