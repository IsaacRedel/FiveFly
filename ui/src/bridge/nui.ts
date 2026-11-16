import type { NuiResponse } from "../types";

export type UiOrigin = "phone" | "panel";

type FiveFYWindow = Window & {
    GetParentResourceName?: () => string;
    resourceName?: string;
    components?: { setGallery?: (options: unknown) => void };
    setGallery?: (options: unknown) => void;
    SetGallery?: (options: unknown) => void;
};

const fivefyWindow = (typeof window !== "undefined" ? window : {}) as FiveFYWindow;
let uiOrigin: UiOrigin = "phone";

/** Set once by each shell so the client knows which UI started playback. */
export function setUiOrigin(origin: UiOrigin) {
    uiOrigin = origin;
}

export function getUiOrigin() {
    return uiOrigin;
}

function hasNuiParent() {
    return typeof fivefyWindow.GetParentResourceName === "function";
}

function hasLbPhoneResourceName() {
    return typeof fivefyWindow.resourceName === "string" && fivefyWindow.resourceName.length > 0;
}

/** True in a regular browser (vite dev server, preview, GitHub Pages demo). */
export function isDevMode() {
    return !hasLbPhoneResourceName() && !hasNuiParent();
}

export function getResourceName() {
    if (hasLbPhoneResourceName()) return fivefyWindow.resourceName as string;
    if (hasNuiParent()) return (fivefyWindow.GetParentResourceName as () => string)();
    return "fivefy";
}

export async function fetchNui<T>(action: string, payload: Record<string, unknown> = {}, fallback?: T): Promise<NuiResponse<T>> {
    if (isDevMode()) {
        return { ok: true, data: fallback as T };
    }

    try {
        const response = await fetch(`https://${getResourceName()}/${action}`, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify({ ...payload, _origin: uiOrigin })
        });

        if (!response.ok) {
            return { ok: false, error: "http_error" };
        }

        return (await response.json()) as NuiResponse<T>;
    } catch (error) {
        return { ok: false, error: String(error) };
    }
}

/** Opens the lb-phone gallery picker. Resolves null outside lb-phone or when cancelled. */
export function selectLbPhoneGalleryPhoto(): Promise<string | null> {
    const setGallery = fivefyWindow.components?.setGallery || fivefyWindow.setGallery || fivefyWindow.SetGallery;

    if (typeof setGallery !== "function") {
        return Promise.resolve(null);
    }

    return new Promise((resolve) => {
        let settled = false;
        const finish = (photo: string | null) => {
            if (settled) return;
            settled = true;
            resolve(photo);
        };

        setGallery({
            includeImages: true,
            includeVideos: false,
            allowExternal: false,
            multiSelect: false,
            onSelect(data: unknown) {
                const item = Array.isArray(data) ? data[0] : data;
                let photo = "";

                if (typeof item === "string") {
                    photo = item;
                } else if (item && typeof item === "object") {
                    const record = item as { src?: unknown; url?: unknown; link?: unknown };
                    photo = String(record.src || record.url || record.link || "");
                }

                finish(photo || null);
            },
            onClose() {
                finish(null);
            }
        });
    });
}

export function hasLbPhoneGallery() {
    return typeof (fivefyWindow.components?.setGallery || fivefyWindow.setGallery || fivefyWindow.SetGallery) === "function";
}

export async function copyTextToClipboard(text: string) {
    const value = String(text || "");

    if (!value) return false;

    try {
        if (navigator.clipboard?.writeText) {
            await navigator.clipboard.writeText(value);
            return true;
        }
    } catch {
        // CEF can expose navigator.clipboard but still deny it outside a secure context.
    }

    const textarea = document.createElement("textarea");
    textarea.value = value;
    textarea.setAttribute("readonly", "true");
    textarea.style.position = "fixed";
    textarea.style.left = "-9999px";
    textarea.style.top = "-9999px";
    document.body.appendChild(textarea);
    textarea.select();

    try {
        return document.execCommand("copy");
    } catch {
        return false;
    } finally {
        textarea.remove();
    }
}
