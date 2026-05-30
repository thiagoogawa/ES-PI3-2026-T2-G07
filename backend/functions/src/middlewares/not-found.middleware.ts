/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Middleware de apoio ao pipeline HTTP.
 * Atua no encerramento de rotas nao encontradas e garante uma
 * resposta uniforme quando o endpoint nao existe.
 */

import {NextFunction, Request, Response} from "express";
import {HTTP_STATUS} from "../core/http/http-status";

export const notFoundMiddleware = (
  request: Request,
  response: Response,
  _next: NextFunction,
): void => {
  response.status(HTTP_STATUS.NOT_FOUND).json({
    success: false,
    error: {
      code: "ROUTE_NOT_FOUND",
      message: `Route ${request.method} ${request.originalUrl} not found`,
    },
  });
};
