/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Utilitario HTTP compartilhado pelo backend.
 * Centraliza convencoes de resposta, status e execucao segura
 * para reduzir repeticao nos controllers da API.
 */

export const HTTP_STATUS = {
  OK: 200,
  CREATED: 201,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  METHOD_NOT_ALLOWED: 405,
  CONFLICT: 409,
  UNPROCESSABLE_ENTITY: 422,
  INTERNAL_SERVER_ERROR: 500,
} as const;
