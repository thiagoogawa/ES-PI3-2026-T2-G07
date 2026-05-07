import {DecodedIdToken} from "firebase-admin/auth";
import {
  FieldValue,
  Transaction,
} from "firebase-admin/firestore";
import {adminDb} from "../../config/firebase-admin";
import {
  isRecord,
  readBoolean,
  readNumber,
  readRecord,
  readString,
  toIsoDate,
} from "../../utils/firestore-helpers";

export interface PortfolioPosition {
  startupId: string;
  startupName: string;
  quantity: number;
  averagePrice: number;
  investedAmount: number;
}

export interface UserAccount {
  uid: string;
  email: string | null;
  name: string | null;
  cpf: string | null;
  phone: string | null;
  picture: string | null;
  roles: string[];
  balance: number;
  reservedBalance: number;
  mfaEnabled: boolean;
  portfolio: Record<string, PortfolioPosition>;
  createdAt: string | null;
  updatedAt: string | null;
}

const DEFAULT_BALANCE = 100000;
const usersCollection = adminDb.collection("usuarios");

const normalizePosition = (
  startupId: string,
  value: unknown,
): PortfolioPosition | null => {
  if (!isRecord(value)) {
    return null;
  }

  const quantity = readNumber(value, ["quantity", "quantidade"], 0);
  const tokenQuantity = readNumber(value, ["quantidadeTokens"], quantity);
  const normalizedQuantity = tokenQuantity > 0 ? tokenQuantity : quantity;
  if (normalizedQuantity <= 0) {
    return null;
  }

  const averagePrice = readNumber(
    value,
    ["averagePrice", "precoMedio"],
    0,
  );
  const investedAmount = readNumber(
    value,
    ["investedAmount", "valorInvestido", "valorInvestidoTotal"],
    normalizedQuantity * averagePrice,
  );

  return {
    startupId,
    startupName: readString(value, "startupName", "nomeStartup") ?? startupId,
    quantity: normalizedQuantity,
    averagePrice,
    investedAmount,
  };
};

const normalizePortfolioFromDocuments = (
  entries: Array<[string, Record<string, unknown>]>,
): Record<string, PortfolioPosition> => {
  return entries.reduce<Record<string, PortfolioPosition>>(
    (portfolio, [startupId, value]) => {
      const position = normalizePosition(startupId, value);
      if (position) {
        portfolio[startupId] = position;
      }

      return portfolio;
    },
    {},
  );
};

export const normalizePortfolio = (
  rawPortfolio: unknown,
): Record<string, PortfolioPosition> => {
  if (!isRecord(rawPortfolio)) {
    return {};
  }

  return Object.entries(rawPortfolio).reduce<Record<string, PortfolioPosition>>(
    (portfolio, [startupId, value]) => {
      const position = normalizePosition(startupId, value);
      if (position) {
        portfolio[startupId] = position;
      }

      return portfolio;
    },
    {},
  );
};

export const normalizeUserAccount = (
  uid: string,
  source: Record<string, unknown>,
  fallback: Partial<UserAccount> = {},
): UserAccount => {
  const fallbackPortfolio = fallback.portfolio ?? {};
  const sourcePortfolio = readRecord(source, "carteira", "portfolio") ?? {};
  const rawPortfolio = Object.keys(fallbackPortfolio).length > 0 ?
    fallbackPortfolio :
    sourcePortfolio;

  return {
    uid,
    email: readString(source, "email") ?? fallback.email ?? null,
    name: readString(source, "nome", "name") ?? fallback.name ?? null,
    cpf: readString(source, "cpf") ?? fallback.cpf ?? null,
    phone: readString(source, "telefone", "phone") ?? fallback.phone ?? null,
    picture:
      readString(source, "fotoPerfil", "picture") ??
      fallback.picture ??
      null,
    roles: normalizeRoles(source, fallback.roles),
    balance: readNumber(
      source,
      ["saldoDisponivel", "balance"],
      fallback.balance ?? DEFAULT_BALANCE,
    ),
    reservedBalance: readNumber(
      source,
      ["saldoReservado", "reservedBalance"],
      fallback.reservedBalance ?? 0,
    ),
    mfaEnabled:
      readBoolean(source, "mfaAtivo", "mfaEnabled") ??
      fallback.mfaEnabled ??
      false,
    portfolio: isRecord(rawPortfolio) ? normalizePortfolio(rawPortfolio) : {},
    createdAt: toIsoDate(source.createdAt) ?? fallback.createdAt ?? null,
    updatedAt: toIsoDate(source.updatedAt) ?? fallback.updatedAt ?? null,
  };
};

const normalizeRoles = (
  source: Record<string, unknown>,
  fallback?: string[],
): string[] => {
  const roles = new Set<String>(fallback ?? []);
  const roleMap = readRecord(source, "papeis", "roles") ?? {};

  Object.entries(roleMap).forEach(([key, value]) => {
    if (value === true) {
      roles.add(key);
    }
  });

  return Array.from(roles).map((role) => role.toString());
};

const buildDefaultUserDocument = (decodedToken: DecodedIdToken) => {
  return {
    uid: decodedToken.uid,
    email: decodedToken.email ?? null,
    nome: decodedToken.name ?? null,
    telefone: decodedToken.phone_number ?? null,
    cpf: null,
    fotoPerfil: decodedToken.picture ?? null,
    saldoDisponivel: DEFAULT_BALANCE,
    saldoReservado: 0,
    mfaAtivo: false,
    carteira: {},
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
};

export const getUserDocRef = (uid: string) => usersCollection.doc(uid);
export const getUserInvestmentsCollectionRef = (uid: string) => {
  return getUserDocRef(uid).collection("investimentos");
};

export const getUserInvestmentDocRef = (uid: string, startupId: string) => {
  return getUserInvestmentsCollectionRef(uid).doc(startupId);
};

export const serializeInvestmentPosition = (position: PortfolioPosition) => {
  return {
    startupId: position.startupId,
    quantidadeTokens: position.quantity,
    precoMedio: position.averagePrice,
    valorInvestidoTotal: position.investedAmount,
    updatedAt: FieldValue.serverTimestamp(),
  };
};

export const syncInvestmentsInTransaction = (
  transaction: Transaction,
  uid: string,
  currentPortfolio: Record<string, PortfolioPosition>,
  nextPortfolio: Record<string, PortfolioPosition>,
): void => {
  const currentIds = new Set(Object.keys(currentPortfolio));
  const nextIds = new Set(Object.keys(nextPortfolio));

  for (const [startupId, position] of Object.entries(nextPortfolio)) {
    transaction.set(
      getUserInvestmentDocRef(uid, startupId),
      serializeInvestmentPosition(position),
      {merge: true},
    );
  }

  currentIds.forEach((startupId) => {
    if (!nextIds.has(startupId)) {
      transaction.delete(getUserInvestmentDocRef(uid, startupId));
    }
  });
};

const loadInvestments = async (
  uid: string,
): Promise<Record<string, PortfolioPosition>> => {
  const snapshot = await getUserInvestmentsCollectionRef(uid).get();

  return normalizePortfolioFromDocuments(
    snapshot.docs.map((doc) => [doc.id, doc.data()]),
  );
};

export const getOrCreateUserAccount = async (
  decodedToken: DecodedIdToken,
): Promise<UserAccount> => {
  const userRef = getUserDocRef(decodedToken.uid);
  const [snapshot, investments] = await Promise.all([
    userRef.get(),
    loadInvestments(decodedToken.uid),
  ]);

  const fallback: Partial<UserAccount> = {
    email: decodedToken.email ?? null,
    name: decodedToken.name ?? null,
    phone: decodedToken.phone_number ?? null,
    picture: decodedToken.picture ?? null,
    roles: [],
    balance: DEFAULT_BALANCE,
    reservedBalance: 0,
    mfaEnabled: false,
    portfolio: investments,
  };

  if (!snapshot.exists) {
    await userRef.set(buildDefaultUserDocument(decodedToken));

    return normalizeUserAccount(decodedToken.uid, {}, fallback);
  }

  return normalizeUserAccount(
    decodedToken.uid,
    snapshot.data() ?? {},
    fallback,
  );
};

export const syncBasicUserProfile = async (
  decodedToken: DecodedIdToken,
): Promise<void> => {
  const userRef = getUserDocRef(decodedToken.uid);

  const profileUpdate: Record<string, unknown> = {
    uid: decodedToken.uid,
    email: decodedToken.email ?? null,
    nome: decodedToken.name ?? null,
    telefone: decodedToken.phone_number ?? null,
    mfaAtivo: false,
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (decodedToken.picture) {
    profileUpdate.fotoPerfil = decodedToken.picture;
  }

  await userRef.set(
    profileUpdate,
    {merge: true},
  );
};

export const creditUserBalance = async (
  uid: string,
  amount: number,
): Promise<void> => {
  await getUserDocRef(uid).set(
    {
      uid,
      saldoDisponivel: FieldValue.increment(amount),
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
};

interface UpdateUserProfileInput {
  name: string;
  cpf: string;
  phone: string;
  picture?: string | null;
}

export const updateUserProfile = async (
  uid: string,
  input: UpdateUserProfileInput,
): Promise<void> => {
  await getUserDocRef(uid).set(
    {
      uid,
      nome: input.name,
      cpf: input.cpf,
      telefone: input.phone,
      fotoPerfil: input.picture ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
};
