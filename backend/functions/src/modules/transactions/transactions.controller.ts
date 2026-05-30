/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Controller HTTP do modulo de transacoes.
 * Traduz requisicoes e respostas Express para chamadas de alto
 * nivel nas regras de negocio do respectivo modulo.
 */

import {Request, Response} from "express";
import {AuthError} from "../../core/errors/auth-error";
import {HTTP_STATUS} from "../../core/http/http-status";
import {successResponse} from "../../core/http/success-response";
import {TransactionsService} from "./transactions.service";

export class TransactionsController {
  static async list(request: Request, response: Response): Promise<void> {
    if (!request.user) {
      throw new AuthError();
    }

    const transactions = await TransactionsService.listByUser(
      request.user.uid,
      {
        startupId: request.query.startupId?.toString(),
        side: request.query.side?.toString(),
      },
    );

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(transactions, "Transactions fetched successfully"));
  }
}
