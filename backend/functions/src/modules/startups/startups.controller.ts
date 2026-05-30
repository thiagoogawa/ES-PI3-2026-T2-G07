/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Controller HTTP do modulo de startups.
 * Traduz requisicoes e respostas Express para chamadas de alto
 * nivel nas regras de negocio do respectivo modulo.
 */

import {Request, Response} from "express";
import {AuthError} from "../../core/errors/auth-error";
import {HTTP_STATUS} from "../../core/http/http-status";
import {successResponse} from "../../core/http/success-response";
import {OffersService} from "../offers/offers.service";
import {StartupsService} from "./startups.service";

export class StartupsController {
  static async list(request: Request, response: Response): Promise<void> {
    const startups = await StartupsService.list({
      search: request.query.search?.toString(),
      stage: request.query.stage?.toString(),
    });

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(startups, "Startups fetched successfully"));
  }

  static async getById(request: Request, response: Response): Promise<void> {
    const startup = await StartupsService.getById(
      request.params.startupId,
      request.user,
    );

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(startup, "Startup fetched successfully"));
  }

  static async submitQuestion(
    request: Request,
    response: Response,
  ): Promise<void> {
    const question = await StartupsService.submitQuestion(
      request.params.startupId,
      request.user,
      request.body ?? {},
    );

    response
      .status(HTTP_STATUS.CREATED)
      .json(successResponse(question, "Question submitted successfully"));
  }

  static async updateStartup(
    request: Request,
    response: Response,
  ): Promise<void> {
    if (!request.user) {
      throw new AuthError();
    }

    const startup = await StartupsService.updateStartup(
      request.params.startupId,
      request.user,
      request.body ?? {},
    );

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(startup, "Startup updated successfully"));
  }

  static async answerQuestion(
    request: Request,
    response: Response,
  ): Promise<void> {
    if (!request.user) {
      throw new AuthError();
    }

    const startup = await StartupsService.answerQuestion(
      request.params.startupId,
      request.params.questionId,
      request.user,
      request.body ?? {},
    );

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(startup, "Question answered successfully"));
  }

  static async trade(request: Request, response: Response): Promise<void> {
    if (!request.user) {
      throw new AuthError();
    }

    const trade = await OffersService.submitTrade(
      request.user,
      request.params.startupId,
      request.body,
    );

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(trade, "Trade executed successfully"));
  }
}
