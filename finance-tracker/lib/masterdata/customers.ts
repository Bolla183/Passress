import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const customerService = createCrudService(prisma.customer, "name");
