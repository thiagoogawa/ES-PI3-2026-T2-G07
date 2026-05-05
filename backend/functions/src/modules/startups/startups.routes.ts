import {Router} from "express";
import {authMiddleware} from "../../middlewares/auth.middleware";
import {asyncHandler} from "../../core/http/async-handler";
import {StartupsController} from "./startups.controller";

const startupsRouter = Router();

startupsRouter.get("/", asyncHandler(StartupsController.list));
startupsRouter.get("/:startupId", asyncHandler(StartupsController.getById));
startupsRouter.post(
  "/:startupId/questions",
  asyncHandler(StartupsController.submitQuestion),
);
startupsRouter.post(
  "/:startupId/trade",
  authMiddleware,
  asyncHandler(StartupsController.trade),
);

export {startupsRouter};
