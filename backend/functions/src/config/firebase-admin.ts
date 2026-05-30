/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Inicializa e compartilha o acesso administrativo ao Firebase.
 * Concentra app, auth e Firestore para evitar multiplas
 * instancias e padronizar o acesso aos servicos.
 */

import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";

const adminApp = getApps().length > 0 ? getApps()[0] : initializeApp();
const firestoreDatabaseId = process.env.FIRESTORE_DATABASE_ID ?? "mescla-inv";

if (
  process.env.FIRESTORE_EMULATOR_HOST &&
  firestoreDatabaseId !== "(default)"
) {
  console.warn(
    "Ignoring FIRESTORE_EMULATOR_HOST for named Firestore database",
    firestoreDatabaseId,
  );
  delete process.env.FIRESTORE_EMULATOR_HOST;
}

export const adminAuth = getAuth(adminApp);
export const adminDb = getFirestore(adminApp, firestoreDatabaseId);
