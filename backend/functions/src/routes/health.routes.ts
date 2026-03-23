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
