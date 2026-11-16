import { describe, expect, it } from "vitest";
import { createTranslator, greetingKey, normalizeLocale, translateError, translateSection } from "../i18n";
import en from "../i18n/en";
import ptBR from "../i18n/pt-BR";
import { durationToSeconds, formatTime, progressFromSession, resolveLiveProgress } from "../lib/time";
import { moveItem, smartCoverImages } from "../lib/tracks";
import type { PlaybackState } from "../types";

describe("time helpers", () => {
    it("formats and parses durations", () => {
        expect(formatTime(65)).toBe("1:05");
        expect(formatTime(3723)).toBe("1:02:03");
        expect(formatTime(-3)).toBe("0:00");
        expect(durationToSeconds("1:02:03")).toBe(3723);
        expect(durationToSeconds("--:--")).toBe(0);
        expect(durationToSeconds(undefined)).toBe(0);
    });

    it("derives progress from a server session (startedAt in seconds)", () => {
        const now = 1_000_000;
        const session = {
            status: "online",
            currentTrack: { videoId: "a", title: "A", thumbnail: "", duration: "3:00" },
            playback: { position: 10, startedAt: now / 1000 - 5, nonce: 1 }
        } as PlaybackState;

        expect(progressFromSession(session, now).position).toBe(15);
        expect(progressFromSession({ ...session, status: "paused" }, now).position).toBe(10);
    });

    it("never runs past the track duration", () => {
        const progress = resolveLiveProgress({ position: 170, duration: 180, updatedAt: 1_000 }, true, null, 60_000);
        expect(progress.position).toBe(180);
    });
});

describe("track helpers", () => {
    it("moves queue items within bounds", () => {
        expect(moveItem(["a", "b", "c"], 0, 1)).toEqual(["b", "a", "c"]);

        const list = ["a", "b"];
        expect(moveItem(list, 0, -1)).toBe(list);
    });

    it("builds a mosaic from distinct thumbnails", () => {
        const tracks = ["x", "x", "y", "", "z", "w", "v"].map((thumbnail, index) => ({ videoId: String(index), title: "", duration: "", thumbnail }));
        expect(smartCoverImages(tracks)).toEqual(["x", "y", "z", "w"]);
    });
});

describe("i18n", () => {
    it("has the same keys in every language", () => {
        expect(Object.keys(ptBR).sort()).toEqual(Object.keys(en).sort());
    });

    it("interpolates variables and translates error codes", () => {
        const t = createTranslator("pt-BR");

        expect(t("common.tracks", { count: 3 })).toBe("3 músicas");
        expect(translateError(t, "rate_limited")).toBe("Aguarde um instante.");
        expect(translateError(t, "something_new")).toBe("Algo deu errado (something_new).");
        expect(translateSection(t, "history", "fallback")).toBe("Você costuma ouvir");
        expect(translateSection(t, "custom", "Server title")).toBe("Server title");
    });

    it("normalizes locales and picks the greeting by hour", () => {
        expect(normalizeLocale("pt")).toBe("pt-BR");
        expect(normalizeLocale("en-US")).toBe("en");
        expect(normalizeLocale(undefined)).toBe("en");
        expect(greetingKey(8)).toBe("greeting.morning");
        expect(greetingKey(15)).toBe("greeting.afternoon");
        expect(greetingKey(23)).toBe("greeting.evening");
    });
});
