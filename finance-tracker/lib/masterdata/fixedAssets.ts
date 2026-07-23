import { prisma } from "../prisma";
import { createCrudService } from "./crudFactory";

export const fixedAssetService = createCrudService(prisma.fixedAsset, "name");
