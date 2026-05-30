/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Utilitario HTTP compartilhado pelo backend.
 * Centraliza convencoes de resposta, status e execucao segura
 * para reduzir repeticao nos controllers da API.
 */

import {NextFunction, Request, Response} from "express";

type AsyncHandlerFn = (
  request: Request,
  response: Response,
  next: NextFunction,
) => Promise<unknown>;

export const asyncHandler =
  (fn: AsyncHandlerFn) =>
    (request: Request, response: Response, next: NextFunction): void => {
      Promise.resolve(fn(request, response, next)).catch(next);
    };
