import {Router} from "express";
import {
  authMiddleware,
  optionalAuthMiddleware,
} from "../../middlewares/auth.middleware";
import {asyncHandler} from "../../core/http/async-handler";
import {StartupsController} from "./startups.controller";

const startupsRouter = Router();

startupsRouter.get("/", asyncHandler(StartupsController.list));
startupsRouter.get(
  "/:startupId",
  optionalAuthMiddleware,
  asyncHandler(StartupsController.getById),
);
startupsRouter.patch(
  "/:startupId",
  authMiddleware,
  asyncHandler(StartupsController.updateStartup),
);
startupsRouter.post(
  "/:startupId/questions",
  optionalAuthMiddleware,
  asyncHandler(StartupsController.submitQuestion),
);
startupsRouter.patch(
  "/:startupId/questions/:questionId/answer",
  authMiddleware,
  asyncHandler(StartupsController.answerQuestion),
);
startupsRouter.post(
  "/:startupId/trade",
  authMiddleware,
  asyncHandler(StartupsController.trade),
);

export {startupsRouter};
