import {Router} from "express";
import {asyncHandler} from "../../core/http/async-handler";
import {DevController} from "./dev.controller";

const devRouter = Router();

devRouter.post("/seed-demo", asyncHandler(DevController.seedDemo));

export {devRouter};
