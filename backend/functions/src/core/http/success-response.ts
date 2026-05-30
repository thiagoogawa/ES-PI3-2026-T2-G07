/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Utilitario HTTP compartilhado pelo backend.
 * Centraliza convencoes de resposta, status e execucao segura
 * para reduzir repeticao nos controllers da API.
 */

export const successResponse = <T>(data: T, message = "Success") => {
  return {
    success: true,
    message,
    data,
  };
};
