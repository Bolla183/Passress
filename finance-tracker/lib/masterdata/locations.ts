import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const locationService = createCrudService(prisma.location, "name");
