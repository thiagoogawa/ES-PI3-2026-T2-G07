/**
 * Thiago Ryuji Ogawa - RA:24024450
 * Composicao principal do aplicativo Express usado pelas Cloud Functions.
 *
 * Este arquivo registra middlewares globais, serializacao de corpo, CORS e o
 * encadeamento final de tratamento de erro para todas as rotas HTTP da API.
 */

import express, {Router} from "express";
import cors from "cors";
import {router} from "./routes";
import {errorMiddleware} from "./middlewares/error.middleware";
import {notFoundMiddleware} from "./middlewares/not-found.middleware";

type RouteBuilder = (router: Router) => void;

/**
 * Fabrica uma instancia do Express pronta para ser usada pelas funcoes HTTP.
 *
 * O [routeBuilder] permite sobrescrever o conjunto de rotas durante testes ou
 * composicoes especificas, preservando os mesmos middlewares globais.
 */
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

/** Instancia padrao usada pela exportacao principal das Cloud Functions. */
const app = createApp();

export {app, createApp};
