import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const collectionService = createCrudService(prisma.collection, "name");
