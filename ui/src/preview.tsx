/**
 * Browser demo (vite dev server and GitHub Pages). Uses mock data from preview/mockData.ts:
 * no request leaves the page and no audio is played.
 */
import { StrictMode, useState } from "react";
import { createRoot } from "react-dom/client";
import { setUiOrigin } from "./bridge/nui";
import { PREVIEW_API_FALLBACKS } from "./preview/mockData";
import { PanelShell } from "./shells/PanelShell";
import { PhoneShell } from "./shells/PhoneShell";
import { FiveFYProvider } from "./state/store";
import "./styles/index.css";
import "./styles/preview.css";

(window as Window & { __FIVEFY_PREVIEW__?: unknown }).__FIVEFY_PREVIEW__ = PREVIEW_API_FALLBACKS;

type Mode = "phone" | "panel";

const params = new URLSearchParams(window.location.search);

function setParam(name: string, value: string) {
    params.set(name, value);
    window.location.search = params.toString();
}

function Preview() {
    const [mode, setMode] = useState<Mode>(params.get("mode") === "panel" ? "panel" : "phone");
    const lang = params.get("lang")?.startsWith("pt") ? "pt-BR" : "en";

    setUiOrigin(mode);

    return (
        <main className={`preview-page preview-page--${mode}`}>
            <header className="preview-head">
                <div className="preview-title">
                    <span className="preview-mark" aria-hidden="true" />
                    <div>
                        <h1>FiveFY</h1>
                        <p>{lang === "pt-BR" ? "Demo interativa com dados de exemplo." : "Interactive demo with sample data."}</p>
                    </div>
                </div>
                <div className="preview-controls">
                    <div className="preview-toggle" role="group" aria-label="Layout">
                        <button className={mode === "phone" ? "active" : ""} type="button" onClick={() => setMode("phone")}>Phone app</button>
                        <button className={mode === "panel" ? "active" : ""} type="button" onClick={() => setMode("panel")}>Panel</button>
                    </div>
                    <div className="preview-toggle" role="group" aria-label="Language">
                        <button className={lang === "en" ? "active" : ""} type="button" onClick={() => setParam("lang", "en")}>EN</button>
                        <button className={lang === "pt-BR" ? "active" : ""} type="button" onClick={() => setParam("lang", "pt-BR")}>PT-BR</button>
                    </div>
                </div>
            </header>

            {mode === "phone" ? (
                <section className="preview-phone" aria-label="Phone app preview">
                    <FiveFYProvider origin="phone" key="phone">
                        <PhoneShell />
                    </FiveFYProvider>
                </section>
            ) : (
                <section className="preview-panel" aria-label="Panel preview">
                    <FiveFYProvider origin="panel" key="panel">
                        <PanelShell onClose={() => setMode("phone")} />
                    </FiveFYProvider>
                </section>
            )}
        </main>
    );
}

createRoot(document.getElementById("preview-root") as HTMLElement).render(
    <StrictMode>
        <Preview />
    </StrictMode>
);
