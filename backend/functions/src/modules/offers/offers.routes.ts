import {Router} from "express";
import {authMiddleware} from "../../middlewares/auth.middleware";
import {asyncHandler} from "../../core/http/async-handler";
import {OffersController} from "./offers.controller";

const offersRouter = Router();

offersRouter.get("/", asyncHandler(OffersController.list));
offersRouter.post(
  "/",
  authMiddleware,
  asyncHandler(OffersController.create),
);
offersRouter.post(
  "/:offerId/accept",
  authMiddleware,
  asyncHandler(OffersController.accept),
);
offersRouter.post(
  "/:offerId/cancel",
  authMiddleware,
  asyncHandler(OffersController.cancel),
);

export {offersRouter};
