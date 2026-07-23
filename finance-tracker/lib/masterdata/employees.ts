import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const employeeService = createCrudService(prisma.employee, "name");
