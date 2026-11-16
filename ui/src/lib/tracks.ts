import type { Track } from "../types";

export function isFavorite(track: Track | null | undefined, favorites: Track[]) {
    return !!track && favorites.some((favorite) => favorite.videoId === track.videoId);
}

/** Up to four distinct thumbnails for a mosaic playlist cover. */
export function smartCoverImages(tracks: Track[]) {
    return [...new Set(tracks.map((track) => track.thumbnail).filter(Boolean))].slice(0, 4);
}

/** Moves the item at `from` by `direction`, returning a new array (or the same one when out of bounds). */
export function moveItem<T>(list: T[], from: number, direction: -1 | 1) {
    const to = from + direction;

    if (from < 0 || from >= list.length || to < 0 || to >= list.length) {
        return list;
    }

    const next = [...list];
    const [item] = next.splice(from, 1);
    next.splice(to, 0, item);

    return next;
}
