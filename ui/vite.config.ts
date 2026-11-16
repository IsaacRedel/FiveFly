import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = dirname(fileURLToPath(import.meta.url));

/**
 * Two separate builds:
 * - `vite build` (game): phone app + audio engine/panel -> ui/dist, packaged in the release.
 * - `vite build --mode preview` (browser demo): preview page only -> ui/dist-preview, published on GitHub Pages.
 * Nothing imported only by the preview (sample data, demo audio) can end up in ui/dist.
 */
export default defineConfig(({ mode }) => {
    const isPreview = mode === "preview";

    return {
        // Relative paths work both in game (https://cfx-nui-<resource>/ui/dist/) and on GitHub Pages.
        base: "./",
        build: {
            outDir: isPreview ? "dist-preview" : "dist",
            emptyOutDir: true,
            sourcemap: false,
            // FiveM's CEF is Chromium-based but not always recent.
            target: "chrome100",
            rollupOptions: {
                input: isPreview
                    ? { preview: resolve(rootDir, "preview.html") }
                    : { index: resolve(rootDir, "index.html"), engine: resolve(rootDir, "engine.html") }
            }
        },
        server: {
            port: 3002,
            open: "/preview.html"
        },
        plugins: [react()]
    };
});
