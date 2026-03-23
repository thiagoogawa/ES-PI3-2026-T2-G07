import express from "express";
import cors from "cors";
import {router} from "./routes";
import {errorMiddleware} from "./middlewares/error.middleware";
import {notFoundMiddleware} from "./middlewares/not-found.middleware";

const app = express();

app.disable("x-powered-by");

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({extended: true}));

app.use(router);

app.use(notFoundMiddleware);
app.use(errorMiddleware);

export {app};
