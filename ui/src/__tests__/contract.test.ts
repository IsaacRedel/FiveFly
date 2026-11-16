/**
 * Contract between the UI, the client NUI callbacks and the server action registry:
 * every action the UI calls must be handled by Lua, and every forwarded action must exist on the server.
 */
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "../../..");
const read = (path: string) => readFileSync(join(repoRoot, path), "utf8");
const matchAll = (text: string, pattern: RegExp) => [...text.matchAll(pattern)].map((match) => match[1]);

const uiActions = new Set([
    ...matchAll(read("ui/src/bridge/api.ts"), /fetchNui<[^>]*>\(\s*"([\w.-]+)"/g),
    ...matchAll(read("ui/src/engine/panel.tsx"), /fetchNui\(\s*"([\w.-]+)"/g)
]);

const clientBridge = read("client/nui_bridge.lua");
const clientCallbacks = new Set([
    ...matchAll(clientBridge, /RegisterNUICallback\("([\w.-]+)"/g),
    ...matchAll(read("client/panel.lua"), /RegisterNUICallback\("([\w.-]+)"/g),
    ...matchAll(read("client/audio_engine.lua"), /RegisterNUICallback\("([\w.-]+)"/g),
    // Callbacks registered in loops over lists of names.
    ...matchAll(clientBridge, /^\s+"([\w.-]+)",?$/gm),
    ...matchAll(clientBridge, /ipairs\(\{\s*"([\w.-]+)"/g),
    ...matchAll(clientBridge, /ipairs\(\{[^}]*?,\s*"([\w.-]+)"\s*\}/g)
]);

const serverActions = new Set(
    readdirSync(join(repoRoot, "server/actions")).flatMap((file) => matchAll(read(`server/actions/${file}`), /Actions\.Register\("([\w.-]+)"/g))
);

const forwardedBlock = clientBridge.match(/FORWARDED_ACTIONS <const> = \{([\s\S]*?)\}/)?.[1] || "";
const forwardedActions = matchAll(forwardedBlock, /"([\w.-]+)"/g);

// Handled locally by the client, never sent to the server.
const CLIENT_ONLY = new Set(["app.ready", "audio.output.get", "audio.output.set", "audio.volume.set", "audio.mute.set", "panel.close"]);

describe("NUI contract", () => {
    it("finds actions in every layer", () => {
        expect(uiActions.size).toBeGreaterThan(20);
        expect(serverActions.size).toBeGreaterThan(20);
        expect(forwardedActions.length).toBeGreaterThan(10);
    });

    it("every UI action has a client callback", () => {
        const missing = [...uiActions].filter((action) => !clientCallbacks.has(action));
        expect(missing).toEqual([]);
    });

    it("every server-bound action exists in the server registry", () => {
        const serverBound = [...uiActions].filter((action) => !CLIENT_ONLY.has(action));
        const missing = serverBound.filter((action) => !serverActions.has(action));
        expect(missing).toEqual([]);
    });

    it("every forwarded action exists in the server registry", () => {
        expect(forwardedActions.filter((action) => !serverActions.has(action))).toEqual([]);
    });

    it("documents every server action in docs/api-contract.md", () => {
        const docs = read("docs/api-contract.md");
        const undocumented = [...serverActions].filter((action) => !docs.includes(`### ${action}`));
        expect(undocumented).toEqual([]);
    });
});
