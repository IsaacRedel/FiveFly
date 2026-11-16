import { createContext, useContext } from "react";
import en, { type MessageKey, type Messages } from "./en";
import ptBR from "./pt-BR";

export type Locale = "en" | "pt-BR";

const dictionaries: Record<Locale, Messages> = {
    en,
    "pt-BR": ptBR
};

export function normalizeLocale(value: unknown): Locale {
    const text = String(value || "").toLowerCase();
    return text.startsWith("pt") ? "pt-BR" : "en";
}

export type Translate = (key: MessageKey, vars?: Record<string, string | number>) => string;

/** `appName` fills the {app} placeholder (Config.Phone.Name, e.g. "FiveFly" or a server's own brand). */
export function createTranslator(locale: Locale, appName = "FiveFly"): Translate {
    const dictionary = dictionaries[locale] || en;

    return (key, vars) => {
        const template = dictionary[key] ?? en[key] ?? key;
        const values: Record<string, string | number> = { app: appName, ...vars };

        return template.replace(/\{(\w+)\}/g, (match, name: string) => (name in values ? String(values[name]) : match));
    };
}

/** Translates a server error code, falling back to a generic message that includes the code. */
export function translateError(t: Translate, code: string) {
    const key = `error.${code}` as MessageKey;
    const message = t(key);

    return message === key ? t("error.unknown", { code }) : message;
}

/** Translates a recommendation/smart playlist section by id, falling back to the server title. */
export function translateSection(t: Translate, id: string, fallback: string) {
    const key = `section.${id}` as MessageKey;
    const message = t(key);

    return message === key ? fallback : message;
}

export function greetingKey(hour = new Date().getHours()): MessageKey {
    if (hour >= 5 && hour < 12) return "greeting.morning";
    if (hour >= 12 && hour < 18) return "greeting.afternoon";
    return "greeting.evening";
}

export const I18nContext = createContext<Translate>(createTranslator("en"));

export function useT() {
    return useContext(I18nContext);
}
