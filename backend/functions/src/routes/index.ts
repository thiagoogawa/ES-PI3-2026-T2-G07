/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Composicao principal das rotas HTTP do backend.
 * Centraliza o encadeamento dos agrupadores usados pelo app
 * Express exposto via Cloud Functions.
 */

import {Router} from "express";
import {healthRouter} from "./health.routes";
import {v1Router} from "./v1.routes";

const router = Router();

router.use("/health", healthRouter);
router.use("/v1", v1Router);

export {router};
