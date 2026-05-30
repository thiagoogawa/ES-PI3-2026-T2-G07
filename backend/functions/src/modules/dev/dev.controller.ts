/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Controller HTTP do modulo de desenvolvimento.
 * Traduz requisicoes e respostas Express para chamadas de alto
 * nivel nas regras de negocio do respectivo modulo.
 */

import {Request, Response} from "express";
import {AppError} from "../../core/errors/app-error";
import {HTTP_STATUS} from "../../core/http/http-status";
import {successResponse} from "../../core/http/success-response";
import {DevService} from "./dev.service";

/**
 * Expõe endpoints utilitarios voltados ao ambiente de desenvolvimento.
 */
export class DevController {
  /**
   * Executa a semeadura de dados demo apos validar a chave esperada no header.
   */
  static async seedDemo(request: Request, response: Response): Promise<void> {
    const expectedSeedKey =
      process.env.SEED_DEMO_KEY ?? "pii3-demo-seed-2026";
    if (request.header("x-seed-key") !== expectedSeedKey) {
      throw new AppError(
        "Invalid seed key",
        HTTP_STATUS.FORBIDDEN,
        "INVALID_SEED_KEY",
      );
    }

    const result = await DevService.seedDemoData(request.body ?? {});

    response
      .status(HTTP_STATUS.CREATED)
      .json(successResponse(result, "Demo data seeded successfully"));
  }
}
