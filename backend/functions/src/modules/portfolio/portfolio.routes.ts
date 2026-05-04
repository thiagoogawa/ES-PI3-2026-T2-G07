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

export {portfolioRouter};
