/**
 * Entry of the resource ui_page (engine.html). It always runs the hidden audio engine; the desktop panel
 * (React + styles) is downloaded only the first time the client opens it (client/panel.lua).
 */
import { fetchNui, setUiOrigin } from "../bridge/nui";
import "./audioEngine.js";

setUiOrigin("panel");

const container = document.getElementById("panel-root") as HTMLElement;
let panelModule: Promise<typeof import("./panel")> | null = null;

/** Hides the panel and releases NUI focus without depending on the React tree. */
function forceClose() {
    container.classList.remove("is-open");
    fetchNui("panel.close");
}

window.addEventListener("message", (event: MessageEvent) => {
    const message = event.data || {};

    if (message.target !== "panel") return;

    if (message.action === "open") {
        panelModule ??= import("./panel");
        panelModule.then((panel) => panel.openPanel()).catch((error) => {
            // A failed chunk must not leave the player with a captured cursor and no UI.
            console.error("[fivefy] could not load the panel", error);
            panelModule = null;
            forceClose();
        });
    } else if (message.action === "close") {
        panelModule?.then((panel) => panel.hidePanel()).catch(() => undefined);
    }
});

// Safety net: Esc always closes the panel when its UI did not render (the panel handles Esc itself otherwise).
window.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && container.classList.contains("is-open") && !container.querySelector(".fivefy-app")) {
        forceClose();
    }
});
