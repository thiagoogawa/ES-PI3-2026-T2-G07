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
authRouter.get(
  "/mfa",
  authMiddleware,
  asyncHandler(AuthController.getMfaStatus),
);
authRouter.post(
  "/mfa/sync",
  authMiddleware,
  asyncHandler(AuthController.syncMfaStatus),
);
authRouter.delete(
  "/mfa",
  authMiddleware,
  asyncHandler(AuthController.disableMfa),
);

export {authRouter};
