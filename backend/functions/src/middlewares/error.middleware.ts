import {NextFunction, Request, Response} from "express";
import * as logger from "firebase-functions/logger";
import {AppError} from "../core/errors/app-error";
import {HTTP_STATUS} from "../core/http/http-status";

export const errorMiddleware = (
  error: unknown,
  request: Request,
  response: Response,
  _next: NextFunction,
): void => {
  if (error instanceof AppError) {
    logger.warn("Application error", {
      method: request.method,
      path: request.originalUrl,
      code: error.code,
      message: error.message,
      details: error.details,
    });

    response.status(error.statusCode).json({
      success: false,
      error: {
        code: error.code,
        message: error.message,
        details: error.details ?? null,
      },
    });
    return;
  }

  logger.error("Unhandled error", {
    method: request.method,
    path: request.originalUrl,
    error: error instanceof Error ? error.message : "Unknown error",
  });

  response.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
    success: false,
    error: {
      code: "INTERNAL_SERVER_ERROR",
      message: "An unexpected error occurred",
    },
  });
};
