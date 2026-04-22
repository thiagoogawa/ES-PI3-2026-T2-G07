import express, {Router} from "express";
import cors from "cors";
import {router} from "./routes";
import {errorMiddleware} from "./middlewares/error.middleware";
import {notFoundMiddleware} from "./middlewares/not-found.middleware";

type RouteBuilder = (router: Router) => void;

const createApp = (
  routeBuilder: RouteBuilder = (resolvedRouter) => {
    resolvedRouter.use(router);
  },
) => {
  const app = express();
  const resolvedRouter = Router();

  app.disable("x-powered-by");

  app.use(cors());
  app.use(express.json());
  app.use(express.urlencoded({extended: true}));

  routeBuilder(resolvedRouter);

  app.use(resolvedRouter);
  app.use(notFoundMiddleware);
  app.use(errorMiddleware);

  return app;
};

const app = createApp();

export {app, createApp};
