import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const loanService = createCrudService(prisma.loan, "lender");
