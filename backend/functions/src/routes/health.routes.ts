/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Rotas de verificacao de saude da API.
 * Fornece um endpoint simples para confirmar disponibilidade
 * do backend em ambientes locais e remotos.
 */

import {Router} from "express";
import {HTTP_STATUS} from "../core/http/http-status";

const healthRouter = Router();

healthRouter.get("/", (_request, response) => {
  response.status(HTTP_STATUS.OK).json({
    success: true,
    message: "API is healthy",
    data: {
      status: "ok",
    },
  });
});

export {healthRouter};
