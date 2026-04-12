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
