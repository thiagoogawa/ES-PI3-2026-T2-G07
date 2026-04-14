import {Router} from "express";
import {devRouter} from "../modules/dev/dev.routes";
import {authRouter} from "../modules/auth/auth.routes";
import {offersRouter} from "../modules/offers/offers.routes";
import {portfolioRouter} from "../modules/portfolio/portfolio.routes";
import {startupsRouter} from "../modules/startups/startups.routes";
import {transactionsRouter} from "../modules/transactions/transactions.routes";

const v1Router = Router();

v1Router.use("/auth", authRouter);
v1Router.use("/dev", devRouter);
v1Router.use("/startups", startupsRouter);
v1Router.use("/offers", offersRouter);
v1Router.use("/portfolio", portfolioRouter);
v1Router.use("/transactions", transactionsRouter);

export {v1Router};
