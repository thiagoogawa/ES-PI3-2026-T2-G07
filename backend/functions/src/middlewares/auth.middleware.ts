/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Middleware de autenticacao das rotas protegidas.
 * Valida o usuario autenticado e injeta no request o contexto
 * necessario para regras de autorizacao posteriores.
 */

import {NextFunction, Request, Response} from "express";
import {AuthService} from "../modules/auth/auth.service";
import {AuthError} from "../core/errors/auth-error";

export const authMiddleware = async (
  request: Request,
  _response: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const decodedToken = await AuthService.verifyIdToken(
      request.header("authorization"),
    );

    request.user = decodedToken;
    next();
  } catch (error) {
    next(error);
  }
};

export const optionalAuthMiddleware = async (
  request: Request,
  _response: Response,
  next: NextFunction,
): Promise<void> => {
  const authorization = request.header("authorization");

  if (!authorization) {
    next();
    return;
  }

  try {
    request.user = await AuthService.verifyIdToken(authorization);
    next();
  } catch (error) {
    if (error instanceof AuthError) {
      next();
      return;
    }

    next(error);
  }
};
