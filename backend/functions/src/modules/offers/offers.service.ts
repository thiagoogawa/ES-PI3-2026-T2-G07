import {DecodedIdToken} from "firebase-admin/auth";
import {FieldValue} from "firebase-admin/firestore";
import {adminDb} from "../../config/firebase-admin";
import {AppError} from "../../core/errors/app-error";
import {ValidationError} from "../../core/errors/validation-error";
import {HTTP_STATUS} from "../../core/http/http-status";
import {
  PortfolioPosition,
  getOrCreateUserAccount,
  getUserDocRef,
  getUserInvestmentsCollectionRef,
  normalizeUserAccount,
  syncInvestmentsInTransaction,
} from "../users/user-account.service";
import {
  readNumber,
  readString,
  toIsoDate,
} from "../../utils/firestore-helpers";

type OfferType = "compra" | "venda";
type OfferStatus = "aberta" | "parcial" | "executada" | "cancelada";

interface CreateOfferInput {
  startupId?: string;
  type?: string;
  quantity?: unknown;
  pricePerToken?: unknown;
}

interface AcceptOfferInput {
  quantity?: unknown;
}

interface SubmitTradeInput {
  type?: string;
  quantity?: unknown;
  pricePerToken?: unknown;
}

interface OfferFilters {
  startupId?: string;
  type?: string;
  status?: string;
  userId?: string;
}

const offersCollection = adminDb.collection("ofertas");
const startupsCollection = adminDb.collection("startups");
const transactionsCollection = adminDb.collection("transacoes");

const toStoredOfferType = (value?: string): OfferType => {
  if (value === "buy" || value === "compra") {
    return "compra";
  }

  if (value === "sell" || value === "venda") {
    return "venda";
  }

  throw new ValidationError(
    "type must be either 'buy'/'compra' or 'sell'/'venda'",
  );
};

const toInternalOfferType = (value?: string): "buy" | "sell" => {
  return value === "venda" || value === "sell" ? "sell" : "buy";
};

const toInternalOfferStatus = (
  value?: string,
): "open" | "partial" | "matched" | "cancelled" => {
  switch (value) {
  case "parcial":
  case "partial":
    return "partial";
  case "executada":
  case "matched":
    return "matched";
  case "cancelada":
  case "cancelled":
    return "cancelled";
  default:
    return "open";
  }
};

const normalizeOffer = (id: string, source: Record<string, unknown>) => {
  const storedType = readString(source, "tipo", "type") ?? "compra";
  const storedStatus = readString(source, "status") ?? "aberta";
  const quantityOriginal = readNumber(
    source,
    ["quantidadeOriginal", "quantityOriginal", "quantity", "quantidade"],
    0,
  );
  const remainingQuantity = readNumber(
    source,
    ["quantidadeRestante", "remainingQuantity"],
    quantityOriginal,
  );
  const pricePerToken = readNumber(
    source,
    ["preco", "pricePerToken", "precoPorToken", "price"],
    0,
  );

  return {
    id,
    startupId: readString(source, "startupId") ?? "",
    startupName: readString(source, "startupName", "startupNome"),
    userId: readString(source, "userId") ?? "",
    userName: readString(source, "userName", "nomeUsuario"),
    type: toInternalOfferType(storedType),
    status: toInternalOfferStatus(storedStatus),
    quantityOriginal,
    quantity: quantityOriginal,
    remainingQuantity,
    pricePerToken,
    totalValue: readNumber(
      source,
      ["totalValue", "valorTotal"],
      remainingQuantity * pricePerToken,
    ),
    createdAt: toIsoDate(source.createdAt),
    updatedAt: toIsoDate(source.updatedAt),
  };
};

const parsePositiveNumber = (
  value: unknown,
  fieldName: string,
): number => {
  const parsedValue =
    typeof value === "number" ? value : Number.parseFloat(String(value));

  if (!Number.isFinite(parsedValue) || parsedValue <= 0) {
    throw new ValidationError(`${fieldName} must be a positive number`);
  }

  return parsedValue;
};

const updateBuyerPosition = (
  portfolio: Record<string, PortfolioPosition>,
  startupId: string,
  startupName: string,
  quantity: number,
  pricePerToken: number,
): Record<string, PortfolioPosition> => {
  const currentPosition = portfolio[startupId] ?? {
    startupId,
    startupName,
    quantity: 0,
    averagePrice: 0,
    investedAmount: 0,
  };

  const investedAmount = currentPosition.investedAmount +
    quantity * pricePerToken;
  const totalQuantity = currentPosition.quantity + quantity;

  return {
    ...portfolio,
    [startupId]: {
      startupId,
      startupName,
      quantity: totalQuantity,
      averagePrice: totalQuantity > 0 ? investedAmount / totalQuantity : 0,
      investedAmount,
    },
  };
};

const updateSellerPosition = (
  portfolio: Record<string, PortfolioPosition>,
  startupId: string,
  quantity: number,
): Record<string, PortfolioPosition> => {
  const currentPosition = portfolio[startupId];
  if (!currentPosition || currentPosition.quantity < quantity) {
    throw new ValidationError("Seller does not have enough tokens");
  }

  const remainingQuantity = currentPosition.quantity - quantity;
  const averagePrice = currentPosition.averagePrice;
  const nextPortfolio = {...portfolio};

  if (remainingQuantity <= 0) {
    delete nextPortfolio[startupId];
    return nextPortfolio;
  }

  nextPortfolio[startupId] = {
    ...currentPosition,
    quantity: remainingQuantity,
    investedAmount: remainingQuantity * averagePrice,
  };

  return nextPortfolio;
};

export class OffersService {
  static async list(filters: OfferFilters) {
    const normalizedType = filters.type ?
      toInternalOfferType(filters.type) :
      null;
    const normalizedStatus = filters.status ?
      toInternalOfferStatus(filters.status) :
      null;

    const snapshot = await offersCollection.get();

    return snapshot.docs
      .map((doc) => normalizeOffer(doc.id, doc.data()))
      .filter((offer) => {
        return !filters.startupId || offer.startupId === filters.startupId;
      })
      .filter((offer) => !normalizedType || offer.type === normalizedType)
      .filter((offer) => !normalizedStatus || offer.status === normalizedStatus)
      .filter((offer) => !filters.userId || offer.userId === filters.userId)
      .sort((left, right) => {
        return (right.createdAt ?? "").localeCompare(left.createdAt ?? "");
      });
  }

  static async create(
    decodedToken: DecodedIdToken,
    input: CreateOfferInput,
  ) {
    const startupId = input.startupId?.trim();
    if (!startupId) {
      throw new ValidationError("startupId is required");
    }

    const type = toStoredOfferType(input.type);
    const quantity = parsePositiveNumber(input.quantity, "quantity");
    const pricePerToken = parsePositiveNumber(
      input.pricePerToken,
      "pricePerToken",
    );

    const [userAccount, startupSnapshot] = await Promise.all([
      getOrCreateUserAccount(decodedToken),
      startupsCollection.doc(startupId).get(),
    ]);

    if (!startupSnapshot.exists) {
      throw new AppError(
        "Startup not found",
        HTTP_STATUS.NOT_FOUND,
        "STARTUP_NOT_FOUND",
      );
    }

    const startupData = startupSnapshot.data() ?? {};
    const startupName = readString(startupData, "nome", "name") ?? startupId;
    const totalValue = quantity * pricePerToken;

    if (type === "compra" && userAccount.balance < totalValue) {
      throw new ValidationError("Insufficient balance to create buy offer");
    }

    if (type === "venda") {
      const userPosition = userAccount.portfolio[startupId];
      if (!userPosition || userPosition.quantity < quantity) {
        throw new ValidationError("Insufficient tokens to create sell offer");
      }
    }

    return adminDb.runTransaction(async (transaction) => {
      const userRef = getUserDocRef(decodedToken.uid);
      const offerRef = offersCollection.doc();
      const payload = {
        startupId,
        startupName,
        userId: decodedToken.uid,
        userName: userAccount.name ?? userAccount.email ?? decodedToken.uid,
        tipo: type,
        quantidadeOriginal: quantity,
        quantidadeRestante: quantity,
        preco: pricePerToken,
        status: "aberta",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (type === "compra") {
        transaction.update(userRef, {
          saldoDisponivel: userAccount.balance - totalValue,
          saldoReservado: userAccount.reservedBalance + totalValue,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      transaction.set(offerRef, payload);

      return normalizeOffer(offerRef.id, payload);
    });
  }

  static async submitTrade(
    decodedToken: DecodedIdToken,
    startupId: string,
    input: SubmitTradeInput,
  ) {
    const normalizedStartupId = startupId.trim();
    if (!normalizedStartupId) {
      throw new ValidationError("startupId is required");
    }

    const type = toStoredOfferType(input.type);
    const quantity = parsePositiveNumber(input.quantity, "quantity");
    const startupSnapshot = await startupsCollection
      .doc(normalizedStartupId)
      .get();

    if (!startupSnapshot.exists) {
      throw new AppError(
        "Startup not found",
        HTTP_STATUS.NOT_FOUND,
        "STARTUP_NOT_FOUND",
      );
    }

    const startupData = startupSnapshot.data() ?? {};
    const startupPrice = readNumber(
      startupData,
      [
        "valorTokenAtual",
        "precoAtual",
        "currentPrice",
        "tokenPrice",
        "valorToken",
      ],
      0,
    );
    const pricePerToken = input.pricePerToken === undefined ?
      startupPrice :
      parsePositiveNumber(input.pricePerToken, "pricePerToken");

    if (pricePerToken <= 0) {
      throw new ValidationError(
        "pricePerToken is required when the startup does not have " +
          "a current token price",
      );
    }

    const oppositeType = type === "compra" ? "sell" : "buy";
    const candidateOffers = (await OffersService.list({
      startupId: normalizedStartupId,
      type: oppositeType,
    }))
      .filter((offer) => offer.status === "open" || offer.status === "partial")
      .filter((offer) => {
        return type === "compra" ?
          offer.pricePerToken <= pricePerToken :
          offer.pricePerToken >= pricePerToken;
      })
      .sort((left, right) => {
        if (left.pricePerToken !== right.pricePerToken) {
          return type === "compra" ?
            left.pricePerToken - right.pricePerToken :
            right.pricePerToken - left.pricePerToken;
        }

        return (left.createdAt ?? "").localeCompare(right.createdAt ?? "");
      });

    let remainingQuantity = quantity;
    const executedMatches = [] as Array<Record<string, unknown>>;

    for (const offer of candidateOffers) {
      if (remainingQuantity <= 0) {
        break;
      }

      const matchedQuantity = Math.min(
        remainingQuantity,
        offer.remainingQuantity,
      );

      try {
        const match = await OffersService.accept(decodedToken, offer.id, {
          quantity: matchedQuantity,
        });
        executedMatches.push(match as Record<string, unknown>);
        remainingQuantity -= matchedQuantity;
      } catch (error) {
        if (
          error instanceof ValidationError &&
          (
            error.message === "Offer is no longer available" ||
            error.message === "Requested quantity exceeds offer balance"
          )
        ) {
          continue;
        }

        throw error;
      }
    }

    const residualOffer = remainingQuantity > 0 ?
      await OffersService.create(decodedToken, {
        startupId: normalizedStartupId,
        type,
        quantity: remainingQuantity,
        pricePerToken,
      }) :
      null;

    return {
      startupId: normalizedStartupId,
      type: toInternalOfferType(type),
      quantity,
      pricePerToken,
      matchedQuantity: quantity - remainingQuantity,
      remainingQuantity,
      status:
        remainingQuantity <= 0 ?
          "executed" :
          executedMatches.length > 0 ?
            "partial" :
            "open",
      matches: executedMatches,
      residualOffer,
    };
  }

  static async accept(
    decodedToken: DecodedIdToken,
    offerId: string,
    input: AcceptOfferInput,
  ) {
    const actingUserAccount = await getOrCreateUserAccount(decodedToken);
    const requestedQuantity = input.quantity === undefined ?
      null :
      parsePositiveNumber(input.quantity, "quantity");

    const result = await adminDb.runTransaction(async (transaction) => {
      const offerRef = offersCollection.doc(offerId);
      const offerSnapshot = await transaction.get(offerRef);

      if (!offerSnapshot.exists) {
        throw new AppError(
          "Offer not found",
          HTTP_STATUS.NOT_FOUND,
          "OFFER_NOT_FOUND",
        );
      }

      const offer = normalizeOffer(
        offerSnapshot.id,
        offerSnapshot.data() ?? {},
      );
      if (offer.status === "matched" || offer.status === "cancelled") {
        throw new ValidationError("Offer is no longer available");
      }

      if (offer.userId === decodedToken.uid) {
        throw new ValidationError("You cannot accept your own offer");
      }

      const matchedQuantity = requestedQuantity ?? offer.remainingQuantity;
      if (matchedQuantity > offer.remainingQuantity) {
        throw new ValidationError("Requested quantity exceeds offer balance");
      }

      const buyerId = offer.type === "sell" ? decodedToken.uid : offer.userId;
      const sellerId = offer.type === "sell" ? offer.userId : decodedToken.uid;

      const buyerRef = getUserDocRef(buyerId);
      const sellerRef = getUserDocRef(sellerId);
      const startupRef = startupsCollection.doc(offer.startupId);

      const [
        buyerSnapshot,
        sellerSnapshot,
        startupSnapshot,
        buyerInvestmentsSnapshot,
        sellerInvestmentsSnapshot,
      ] =
        await Promise.all([
          transaction.get(buyerRef),
          transaction.get(sellerRef),
          transaction.get(startupRef),
          transaction.get(getUserInvestmentsCollectionRef(buyerId)),
          transaction.get(getUserInvestmentsCollectionRef(sellerId)),
        ]);

      if (!startupSnapshot.exists) {
        throw new AppError(
          "Startup not found",
          HTTP_STATUS.NOT_FOUND,
          "STARTUP_NOT_FOUND",
        );
      }

      if (!buyerSnapshot.exists || !sellerSnapshot.exists) {
        throw new AppError(
          "User account not initialized",
          HTTP_STATUS.CONFLICT,
          "USER_ACCOUNT_NOT_INITIALIZED",
        );
      }

      const buyerInvestmentsFallback = Object.fromEntries(
        buyerInvestmentsSnapshot.docs.map((doc) => [doc.id, doc.data()]),
      ) as unknown as Record<string, PortfolioPosition>;
      const sellerInvestmentsFallback = Object.fromEntries(
        sellerInvestmentsSnapshot.docs.map((doc) => [doc.id, doc.data()]),
      ) as unknown as Record<string, PortfolioPosition>;

      const buyerFallback = buyerId === decodedToken.uid ?
        {...actingUserAccount, portfolio: buyerInvestmentsFallback} :
        {portfolio: buyerInvestmentsFallback};
      const sellerFallback = sellerId === decodedToken.uid ?
        {...actingUserAccount, portfolio: sellerInvestmentsFallback} :
        {portfolio: sellerInvestmentsFallback};

      const buyerAccount = normalizeUserAccount(
        buyerId,
        buyerSnapshot.data() ?? {},
        buyerFallback,
      );
      const sellerAccount = normalizeUserAccount(
        sellerId,
        sellerSnapshot.data() ?? {},
        sellerFallback,
      );

      const totalValue = matchedQuantity * offer.pricePerToken;
      if (
        offer.type === "buy" &&
        buyerAccount.reservedBalance < totalValue
      ) {
        throw new ValidationError(
          "Buyer does not have enough reserved balance",
        );
      }


      if (offer.type === "sell" && buyerAccount.balance < totalValue) {
        throw new ValidationError("Buyer does not have enough balance");
      }

      const startupData = startupSnapshot.data() ?? {};
      const startupName =
        readString(startupData, "nome", "name") ??
        offer.startupName ??
        offer.startupId;

      const nextBuyerPortfolio = updateBuyerPosition(
        buyerAccount.portfolio,
        offer.startupId,
        startupName,
        matchedQuantity,
        offer.pricePerToken,
      );
      const nextSellerPortfolio = updateSellerPosition(
        sellerAccount.portfolio,
        offer.startupId,
        matchedQuantity,
      );

      const nextBuyerBalance = offer.type === "sell" ?
        buyerAccount.balance - totalValue :
        buyerAccount.balance;
      const nextBuyerReservedBalance = offer.type === "buy" ?
        buyerAccount.reservedBalance - totalValue :
        buyerAccount.reservedBalance;
      const nextSellerBalance = sellerAccount.balance + totalValue;

      transaction.update(buyerRef, {
        saldoDisponivel: nextBuyerBalance,
        saldoReservado: nextBuyerReservedBalance,
        carteira: nextBuyerPortfolio,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(sellerRef, {
        saldoDisponivel: nextSellerBalance,
        carteira: nextSellerPortfolio,
        updatedAt: FieldValue.serverTimestamp(),
      });

      syncInvestmentsInTransaction(
        transaction,
        buyerId,
        buyerAccount.portfolio,
        nextBuyerPortfolio,
      );
      syncInvestmentsInTransaction(
        transaction,
        sellerId,
        sellerAccount.portfolio,
        nextSellerPortfolio,
      );

      const remainingQuantity = offer.remainingQuantity - matchedQuantity;
      const nextStatus: OfferStatus = remainingQuantity <= 0 ?
        "executada" :
        "parcial";

      const transactionRef = transactionsCollection.doc();
      transaction.update(offerRef, {
        quantidadeRestante: remainingQuantity,
        status: nextStatus,
        updatedAt: FieldValue.serverTimestamp(),
      });

      transaction.set(transactionRef, {
        startupId: offer.startupId,
        buyerId,
        sellerId,
        quantidade: matchedQuantity,
        precoUnitario: offer.pricePerToken,
        totalValue,
        ofertaCompraId: offer.type === "buy" ? offer.id : null,
        ofertaVendaId: offer.type === "sell" ? offer.id : null,
        status: "executada",
        executadaEm: FieldValue.serverTimestamp(),
      });

      transaction.set(startupRef.collection("historicoPrecos").doc(), {
        preco: offer.pricePerToken,
        timestamp: FieldValue.serverTimestamp(),
        origem: "transacao",
        transacaoId: transactionRef.id,
      });
      transaction.set(
        startupRef,
        {
          valorTokenAtual: offer.pricePerToken,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      return {
        offerId: offer.id,
        startupId: offer.startupId,
        startupName,
        quantity: matchedQuantity,
        pricePerToken: offer.pricePerToken,
        totalValue,
        status: nextStatus,
        remainingQuantity,
      };
    });

    return result;
  }
}
