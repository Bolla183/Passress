import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const accountService = createCrudService(prisma.account, "name");
