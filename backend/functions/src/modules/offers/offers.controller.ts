/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Controller HTTP do modulo de ofertas.
 * Traduz requisicoes e respostas Express para chamadas de alto
 * nivel nas regras de negocio do respectivo modulo.
 */

import {Request, Response} from "express";
import {AuthError} from "../../core/errors/auth-error";
import {HTTP_STATUS} from "../../core/http/http-status";
import {successResponse} from "../../core/http/success-response";
import {OffersService} from "./offers.service";

export class OffersController {
  static async list(request: Request, response: Response): Promise<void> {
    const offers = await OffersService.list({
      startupId: request.query.startupId?.toString(),
      type: request.query.type?.toString(),
      status: request.query.status?.toString(),
      userId: request.query.userId?.toString(),
    });

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(offers, "Offers fetched successfully"));
  }

  static async create(request: Request, response: Response): Promise<void> {
    if (!request.user) {
      throw new AuthError();
    }

    const offer = await OffersService.create(request.user, request.body);

    response
      .status(HTTP_STATUS.CREATED)
      .json(successResponse(offer, "Offer created successfully"));
  }

  static async accept(request: Request, response: Response): Promise<void> {
    if (!request.user) {
      throw new AuthError();
    }

    const transaction = await OffersService.accept(
      request.user,
      request.params.offerId,
      request.body,
    );

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(transaction, "Offer accepted successfully"));
  }

  static async cancel(request: Request, response: Response): Promise<void> {
    if (!request.user) {
      throw new AuthError();
    }

    const offer = await OffersService.cancel(
      request.user,
      request.params.offerId,
    );

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(offer, "Offer cancelled successfully"));
  }
}
