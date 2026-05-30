/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Centraliza configuracoes do backend.
 * Mantem variaveis de ambiente e parametros compartilhados para
 * que os modulos usem a mesma base de execucao.
 */

export const env = {
  nodeEnv: process.env.NODE_ENV ?? "development",
};
