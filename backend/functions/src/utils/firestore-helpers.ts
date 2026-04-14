import {Timestamp} from "firebase-admin/firestore";

export const isRecord = (
  value: unknown,
): value is Record<string, unknown> => {
  return typeof value === "object" && value !== null && !Array.isArray(value);
};

export const readString = (
  source: Record<string, unknown>,
  ...keys: string[]
): string | null => {
  for (const key of keys) {
    const value = source[key];
    if (typeof value === "string") {
      const normalizedValue = value.trim();
      return normalizedValue.length > 0 ? normalizedValue : null;
    }
  }

  return null;
};

export const readNumber = (
  source: Record<string, unknown>,
  keys: string[],
  fallback = 0,
): number => {
  for (const key of keys) {
    const value = source[key];

    if (typeof value === "number" && Number.isFinite(value)) {
      return value;
    }

    if (typeof value === "string") {
      const parsedValue = Number.parseFloat(value.replace(",", "."));
      if (Number.isFinite(parsedValue)) {
        return parsedValue;
      }
    }
  }

  return fallback;
};

export const readBoolean = (
  source: Record<string, unknown>,
  ...keys: string[]
): boolean | null => {
  for (const key of keys) {
    const value = source[key];

    if (typeof value === "boolean") {
      return value;
    }
  }

  return null;
};

export const readStringArray = (
  source: Record<string, unknown>,
  ...keys: string[]
): string[] => {
  for (const key of keys) {
    const value = source[key];

    if (Array.isArray(value)) {
      return value
        .filter((item): item is string => typeof item === "string")
        .map((item) => item.trim())
        .filter(Boolean);
    }

    if (typeof value === "string") {
      return value
        .split(/\||;|,/)
        .map((item) => item.trim())
        .filter(Boolean);
    }
  }

  return [];
};

export const readRecord = (
  source: Record<string, unknown>,
  ...keys: string[]
): Record<string, unknown> | null => {
  for (const key of keys) {
    const value = source[key];
    if (isRecord(value)) {
      return value;
    }
  }

  return null;
};

export const toIsoDate = (value: unknown): string | null => {
  if (value instanceof Timestamp) {
    return value.toDate().toISOString();
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (typeof value === "string") {
    return value;
  }

  return null;
};
