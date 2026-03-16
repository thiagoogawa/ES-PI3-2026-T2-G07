import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";

const adminApp = getApps().length > 0 ? getApps()[0] : initializeApp();

export const adminAuth = getAuth(adminApp);
