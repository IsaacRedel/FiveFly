import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = dirname(fileURLToPath(import.meta.url));

export default defineConfig({
    // Relative paths work both in game (https://cfx-nui-<resource>/ui/dist/) and on GitHub Pages.
    base: "./",
    build: {
        outDir: "dist",
        emptyOutDir: true,
        sourcemap: false,
        // FiveM's CEF is Chromium-based but not always recent.
        target: "chrome100",
        rollupOptions: {
            input: {
                index: resolve(rootDir, "index.html"),
                engine: resolve(rootDir, "engine.html"),
                preview: resolve(rootDir, "preview.html")
            }
        }
    },
    server: {
        port: 3002,
        open: "/preview.html"
    },
    plugins: [react()]
});
