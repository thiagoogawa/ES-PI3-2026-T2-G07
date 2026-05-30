/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Definicao das rotas HTTP do modulo de autenticacao.
 * Declara endpoints, middlewares e vinculacao com os handlers
 * responsaveis por cada operacao exposta.
 */

import {Router} from "express";
import {AuthController} from "./auth.controller";
import {authMiddleware} from "../../middlewares/auth.middleware";
import {asyncHandler} from "../../core/http/async-handler";

const authRouter = Router();

authRouter.get("/me", authMiddleware, asyncHandler(AuthController.whoAmI));
authRouter.post(
  "/profile",
  authMiddleware,
  asyncHandler(AuthController.updateProfile),
);

export {authRouter};
