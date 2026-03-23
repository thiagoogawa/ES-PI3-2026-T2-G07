import {NextFunction, Request, Response} from "express";
import {AuthService} from "../modules/auth/auth.service";

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
