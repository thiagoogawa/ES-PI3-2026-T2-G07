import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {createApp} from "./app";
import {HTTP_STATUS} from "./core/http/http-status";
import {asyncHandler} from "./core/http/async-handler";
import {authMiddleware} from "./middlewares/auth.middleware";
import {AuthController} from "./modules/auth/auth.controller";
import {DevController} from "./modules/dev/dev.controller";
import {OffersController} from "./modules/offers/offers.controller";
import {PortfolioController} from "./modules/portfolio/portfolio.controller";
import {StartupsController} from "./modules/startups/startups.controller";
import {
  TransactionsController,
} from "./modules/transactions/transactions.controller";

setGlobalOptions({maxInstances: 10});

export const api = onRequest(createApp());

export const health = onRequest(createApp((router) => {
  router.get("/", (_request, response) => {
    response.status(HTTP_STATUS.OK).json({
      success: true,
      message: "API is healthy",
      data: {
        status: "ok",
      },
    });
  });
}));

export const getUserProfile = onRequest(createApp((router) => {
  router.get("/", authMiddleware, asyncHandler(AuthController.whoAmI));
}));

export const updateUserProfile = onRequest(createApp((router) => {
  router.post("/", authMiddleware, asyncHandler(AuthController.updateProfile));
}));

export const seedDemo = onRequest(createApp((router) => {
  router.post("/", asyncHandler(DevController.seedDemo));
}));

export const getStartups = onRequest(createApp((router) => {
  router.get("/", asyncHandler(StartupsController.list));
}));

export const getStartupById = onRequest(createApp((router) => {
  router.get("/:startupId", asyncHandler(StartupsController.getById));
}));

export const getOffers = onRequest(createApp((router) => {
  router.get("/", asyncHandler(OffersController.list));
}));

export const createOffer = onRequest(createApp((router) => {
  router.post("/", authMiddleware, asyncHandler(OffersController.create));
}));

export const acceptOffer = onRequest(createApp((router) => {
  router.post(
    "/:offerId/accept",
    authMiddleware,
    asyncHandler(OffersController.accept),
  );
}));

export const getPortfolio = onRequest(createApp((router) => {
  router.get(
    "/",
    authMiddleware,
    asyncHandler(PortfolioController.getPortfolio),
  );
}));

export const getPortfolioDashboard = onRequest(createApp((router) => {
  router.get(
    "/dashboard",
    authMiddleware,
    asyncHandler(PortfolioController.getDashboard),
  );
}));

export const getTransactions = onRequest(createApp((router) => {
  router.get("/", authMiddleware, asyncHandler(TransactionsController.list));
}));

export const helloWorld = onRequest((_request, response) => {
  logger.info("Hello logs!", {structuredData: true});
  response.status(200).send("Hello from Firebase!");
});
