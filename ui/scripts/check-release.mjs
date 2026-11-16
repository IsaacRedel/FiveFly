/**
 * Fails when browser-demo content leaks into a game build or release package.
 * Usage: node scripts/check-release.mjs <directory> [<directory> ...]
 *
 * Checks every file for:
 * - preview-only file names (preview.html, preview-*.js/css, anything under preview-assets);
 * - audio files (the demo tracks must never ship with the resource);
 * - the PREVIEW_MARKER string, set in code that only the preview imports (sample data, demo audio).
 */
import { readdirSync, readFileSync, statSync } from "node:fs";
import { extname, join, relative } from "node:path";

export const PREVIEW_MARKER = "fivefly-preview-only";

const AUDIO_EXTENSIONS = new Set([".mp3", ".ogg", ".oga", ".wav", ".flac", ".m4a", ".aac", ".opus", ".webm"]);
const TEXT_EXTENSIONS = new Set([".js", ".mjs", ".css", ".html", ".json", ".lua", ".md", ".txt", ".svg", ".sql"]);

function walk(directory) {
    return readdirSync(directory).flatMap((name) => {
        const path = join(directory, name);
        return statSync(path).isDirectory() ? walk(path) : [path];
    });
}

export function findLeaks(directory) {
    const leaks = [];

    for (const file of walk(directory)) {
        const name = relative(directory, file).replace(/\\/g, "/");
        const extension = extname(file).toLowerCase();

        if (/(^|\/)preview[^/]*\.(html|js|css)$/i.test(name) || /(^|\/)preview-assets(\/|$)/i.test(name)) {
            leaks.push(`${name}: preview-only file`);
        } else if (AUDIO_EXTENSIONS.has(extension)) {
            leaks.push(`${name}: audio file`);
        } else if (TEXT_EXTENSIONS.has(extension) && readFileSync(file, "utf8").includes(PREVIEW_MARKER)) {
            leaks.push(`${name}: contains preview-only code`);
        }
    }

    return leaks;
}

const directories = process.argv.slice(2);

if (directories.length > 0) {
    const leaks = directories.flatMap((directory) => findLeaks(directory).map((leak) => `${directory}/${leak}`));

    if (leaks.length > 0) {
        console.error("Preview content found in the release:\n" + leaks.map((leak) => `  - ${leak}`).join("\n"));
        process.exit(1);
    }

    console.log(`No preview content in: ${directories.join(", ")}`);
}
