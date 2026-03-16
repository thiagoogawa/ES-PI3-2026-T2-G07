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
