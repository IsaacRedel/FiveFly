import type { PlaybackState, Track } from "../types";

export type Progress = {
    position: number;
    duration: number;
    updatedAt: number;
};

export function formatTime(seconds: number) {
    const safe = Math.max(0, Math.floor(seconds || 0));
    const hours = Math.floor(safe / 3600);
    const minutes = Math.floor((safe % 3600) / 60);
    const rest = String(safe % 60).padStart(2, "0");

    return hours > 0 ? `${hours}:${String(minutes).padStart(2, "0")}:${rest}` : `${minutes}:${rest}`;
}

/** "3:45" or "1:02:03" to seconds. Unknown formats return 0. */
export function durationToSeconds(duration?: string) {
    if (!duration) return 0;

    const parts = duration.split(":").map(Number);
    if (parts.some((part) => Number.isNaN(part))) return 0;

    return parts.reduce((total, part) => total * 60 + part, 0);
}

/** Progress implied by a server session (position at `startedAt`, advancing while online). */
export function progressFromSession(session?: PlaybackState | null, now = Date.now()): Progress {
    const position = Math.max(0, Number(session?.playback?.position) || 0);
    const duration = durationToSeconds(session?.currentTrack?.duration);
    const startedAt = Number(session?.playback?.startedAt) || 0;
    const elapsed = session?.status === "online" && startedAt > 0 ? Math.max(0, now / 1000 - startedAt) : 0;
    const live = position + elapsed;

    return { position: duration > 0 ? Math.min(duration, live) : live, duration, updatedAt: now };
}

/** Advances a stored progress snapshot to `clock` while playing. */
export function resolveLiveProgress(progress: Progress, isPlaying: boolean, track?: Track | null, clock = Date.now()): Progress {
    const duration = progress.duration || durationToSeconds(track?.duration);
    const updatedAt = progress.updatedAt || clock;
    const elapsed = isPlaying ? Math.max(0, (clock - updatedAt) / 1000) : 0;
    const live = (Number(progress.position) || 0) + elapsed;

    return { position: duration > 0 ? Math.min(duration, live) : live, duration, updatedAt };
}
