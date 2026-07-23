import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const bankAccountService = createCrudService(prisma.bankAccount, "name");
