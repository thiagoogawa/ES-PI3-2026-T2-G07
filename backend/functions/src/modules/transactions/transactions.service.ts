import {adminDb} from "../../config/firebase-admin";
import {readNumber, readString, toIsoDate} from "../../utils/firestore-helpers";

interface TransactionFilters {
  startupId?: string;
  side?: string;
}

const transactionsCollection = adminDb.collection("transacoes");

export class TransactionsService {
  static async listByUser(userId: string, filters: TransactionFilters) {
    const [buySnapshot, sellSnapshot] = await Promise.all([
      transactionsCollection.where("buyerId", "==", userId).get(),
      transactionsCollection.where("sellerId", "==", userId).get(),
    ]);

    const transactionsMap = new Map<string, Record<string, unknown>>();

    [...buySnapshot.docs, ...sellSnapshot.docs].forEach((doc) => {
      transactionsMap.set(doc.id, doc.data());
    });

    return Array.from(transactionsMap.entries())
      .map(([id, source]) => {
        const buyerId = readString(source, "buyerId", "buyerUserId") ?? "";
        const side = buyerId === userId ? "buy" : "sell";

        return {
          id,
          startupId: readString(source, "startupId") ?? "",
          buyerId,
          sellerId: readString(source, "sellerId", "sellerUserId") ?? "",
          side,
          quantity: readNumber(source, ["quantidade", "quantity"], 0),
          pricePerToken: readNumber(
            source,
            ["precoUnitario", "pricePerToken", "precoPorToken"],
            0,
          ),
          totalValue: readNumber(source, ["totalValue", "valorTotal"], 0),
          status: readString(source, "status") ?? "executada",
          executedAt: toIsoDate(source.executadaEm ?? source.createdAt),
          buyOfferId: readString(source, "ofertaCompraId", "buyOfferId"),
          sellOfferId: readString(source, "ofertaVendaId", "sellOfferId"),
        };
      })
      .filter((item) => {
        return !filters.startupId || item.startupId === filters.startupId;
      })
      .filter((item) => !filters.side || item.side === filters.side)
      .sort((left, right) => {
        return (right.executedAt ?? "").localeCompare(left.executedAt ?? "");
      });
  }
}
