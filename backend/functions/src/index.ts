import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {app} from "./app";

setGlobalOptions({maxInstances: 10});

export const api = onRequest(app);

export const helloWorld = onRequest((_request, response) => {
  logger.info("Hello logs!", {structuredData: true});
  response.status(200).send("Hello from Firebase!");
});
