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
