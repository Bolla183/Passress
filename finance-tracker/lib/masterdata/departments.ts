import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const departmentService = createCrudService(prisma.department, "name");
