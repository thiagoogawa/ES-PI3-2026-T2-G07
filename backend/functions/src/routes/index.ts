import {Router} from "express";
import {healthRouter} from "./health.routes";
import {v1Router} from "./v1.routes";

const router = Router();

router.use("/health", healthRouter);
router.use("/v1", v1Router);

export {router};
