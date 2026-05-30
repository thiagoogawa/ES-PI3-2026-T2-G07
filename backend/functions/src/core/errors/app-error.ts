/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Define erros de dominio usados pela API.
 * Essas classes padronizam status, codigo e mensagem para que o
 * tratamento de falhas seja consistente entre modulos.
 */

/**
 * Base application error with normalized HTTP metadata.
 */
export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code: string;
  public readonly details?: unknown;

  /**
   * Creates a normalized application error.
   */
  constructor(
    message: string,
    statusCode = 500,
    code = "INTERNAL_SERVER_ERROR",
    details?: unknown,
  ) {
    super(message);
    this.name = "AppError";
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
  }
}
