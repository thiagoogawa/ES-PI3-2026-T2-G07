/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Extensoes de tipos usadas pelo backend.
 * Complementa contratos do Express e outras bibliotecas para
 * representar corretamente dados enriquecidos pela aplicacao.
 */

import {DecodedIdToken} from "firebase-admin/auth";

declare global {
  namespace Express {
    interface Request {
      user?: DecodedIdToken;
    }
  }
}

export {};
