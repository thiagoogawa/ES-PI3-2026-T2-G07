import {Router} from "express";
import {asyncHandler} from "../../core/http/async-handler";
import {StartupsController} from "./startups.controller";

const startupsRouter = Router();

startupsRouter.get("/", asyncHandler(StartupsController.list));
startupsRouter.get("/:startupId", asyncHandler(StartupsController.getById));

export {startupsRouter};
