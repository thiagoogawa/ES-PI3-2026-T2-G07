/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Utilitario para extrair o bearer token de requisicoes.
 * Padroniza a leitura do header Authorization antes da
 * validacao realizada pelo modulo de autenticacao.
 */

import {AuthError} from "../core/errors/auth-error";

export const extractBearerToken = (
  authorizationHeader?: string,
): string => {
  if (!authorizationHeader) {
    throw new AuthError(
      "Authorization header is required",
      "MISSING_AUTH_HEADER",
    );
  }

  if (!authorizationHeader.startsWith("Bearer ")) {
    throw new AuthError(
      "Authorization header must use Bearer token",
      "INVALID_AUTH_SCHEME",
    );
  }

  const token = authorizationHeader.substring(7).trim();

  if (!token) {
    throw new AuthError("Bearer token is empty", "EMPTY_BEARER_TOKEN");
  }

  return token;
};
