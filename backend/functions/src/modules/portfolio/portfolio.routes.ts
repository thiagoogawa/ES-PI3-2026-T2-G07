/**
 * Thiago Ryuji Ogawa - RA:24024450
 * Lucca Schroelder Scovini - RA: 24011609
 *
 * Definicao das rotas HTTP do modulo de portfolio.
 * Declara endpoints, middlewares e vinculacao com os handlers
 * responsaveis por cada operacao exposta.
 */

import {Router} from "express";
import {authMiddleware} from "../../middlewares/auth.middleware";
import {asyncHandler} from "../../core/http/async-handler";
import {PortfolioController} from "./portfolio.controller";

const portfolioRouter = Router();

portfolioRouter.get(
  "/",
  authMiddleware,
  asyncHandler(PortfolioController.getPortfolio),
);
portfolioRouter.get(
  "/dashboard",
  authMiddleware,
  asyncHandler(PortfolioController.getDashboard),
);
portfolioRouter.post(
  "/deposit",
  authMiddleware,
  asyncHandler(PortfolioController.depositBalance),
);

export {portfolioRouter};
