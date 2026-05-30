/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Define erros de dominio usados pela API.
 * Essas classes padronizam status, codigo e mensagem para que o
 * tratamento de falhas seja consistente entre modulos.
 */

import {AppError} from "./app-error";

/**
 * Authentication-related application error.
 */
export class AuthError extends AppError {
  /**
   * Creates an authentication error payload.
   */
  constructor(
    message = "Authentication required",
    code = "UNAUTHENTICATED",
    details?: unknown,
  ) {
    super(message, 401, code, details);
    this.name = "AuthError";
  }
}
