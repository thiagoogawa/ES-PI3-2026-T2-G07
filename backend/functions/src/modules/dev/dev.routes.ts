/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Definicao das rotas HTTP do modulo de desenvolvimento.
 * Declara endpoints, middlewares e vinculacao com os handlers
 * responsaveis por cada operacao exposta.
 */

import {Router} from "express";
import {asyncHandler} from "../../core/http/async-handler";
import {DevController} from "./dev.controller";

const devRouter = Router();
/**
 * Router com endpoints de apoio usados apenas para preparar dados de teste.
 */

devRouter.post("/seed-demo", asyncHandler(DevController.seedDemo));

export {devRouter};
