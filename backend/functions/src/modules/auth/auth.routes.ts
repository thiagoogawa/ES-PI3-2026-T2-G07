import {Router} from "express";
import {AuthController} from "./auth.controller";
import {authMiddleware} from "../../middlewares/auth.middleware";
import {asyncHandler} from "../../core/http/async-handler";

const authRouter = Router();

authRouter.get("/me", authMiddleware, asyncHandler(AuthController.whoAmI));

export {authRouter};
