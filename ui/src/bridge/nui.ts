import type { NuiResponse } from "../types";

export type UiOrigin = "phone" | "panel";

type FiveFlyWindow = Window & {
    GetParentResourceName?: () => string;
    resourceName?: string;
    components?: { setGallery?: (options: unknown) => void };
    setGallery?: (options: unknown) => void;
    SetGallery?: (options: unknown) => void;
};

const fiveflyWindow = (typeof window !== "undefined" ? window : {}) as FiveFlyWindow;
let uiOrigin: UiOrigin = "phone";

/** Set once by each shell so the client knows which UI started playback. */
export function setUiOrigin(origin: UiOrigin) {
    uiOrigin = origin;
}

export function getUiOrigin() {
    return uiOrigin;
}

function hasNuiParent() {
    return typeof fiveflyWindow.GetParentResourceName === "function";
}

function hasLbPhoneResourceName() {
    return typeof fiveflyWindow.resourceName === "string" && fiveflyWindow.resourceName.length > 0;
}

/** True in a regular browser (vite dev server, preview, GitHub Pages demo). */
export function isDevMode() {
    return !hasLbPhoneResourceName() && !hasNuiParent();
}

export function getResourceName() {
    if (hasLbPhoneResourceName()) return fiveflyWindow.resourceName as string;
    if (hasNuiParent()) return (fiveflyWindow.GetParentResourceName as () => string)();
    return "fivefly";
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
    const setGallery = fiveflyWindow.components?.setGallery || fiveflyWindow.setGallery || fiveflyWindow.SetGallery;

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
    return typeof (fiveflyWindow.components?.setGallery || fiveflyWindow.setGallery || fiveflyWindow.SetGallery) === "function";
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
