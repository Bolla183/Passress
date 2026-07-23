import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const paymentMethodService = createCrudService(prisma.paymentMethod, "name");
