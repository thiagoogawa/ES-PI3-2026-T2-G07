/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Definicao das rotas HTTP do modulo de transacoes.
 * Declara endpoints, middlewares e vinculacao com os handlers
 * responsaveis por cada operacao exposta.
 */

import {Router} from "express";
import {authMiddleware} from "../../middlewares/auth.middleware";
import {asyncHandler} from "../../core/http/async-handler";
import {TransactionsController} from "./transactions.controller";

const transactionsRouter = Router();

transactionsRouter.get(
  "/",
  authMiddleware,
  asyncHandler(TransactionsController.list),
);

export {transactionsRouter};
