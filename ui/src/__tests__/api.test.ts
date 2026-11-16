import { describe, expect, it } from "vitest";
import { playTrack } from "../bridge/api";
import type { Track } from "../types";

const tracks: Track[] = Array.from({ length: 120 }, (_, index) => ({ videoId: `t${index}`, title: `T${index}`, thumbnail: "", duration: "3:00" }));

describe("playTrack", () => {
    it("sends a window of at most 50 tracks containing the chosen one", async () => {
        const response = await playTrack(tracks[80], tracks);
        const session = response.data!.session;

        expect(session.queue).toHaveLength(50);
        expect(session.queue[(session.currentIndex ?? 1) - 1].videoId).toBe("t80");
    });

    it("keeps short lists whole and in order", async () => {
        const response = await playTrack(tracks[2], tracks.slice(0, 5));
        const session = response.data!.session;

        expect(session.queue.map((track) => track.videoId)).toEqual(["t0", "t1", "t2", "t3", "t4"]);
        expect(session.currentIndex).toBe(3);
    });

    it("puts a track that is not in the list first", async () => {
        const extra = { ...tracks[0], videoId: "extra" };
        const session = (await playTrack(extra, tracks.slice(0, 3))).data!.session;

        expect(session.queue[0].videoId).toBe("extra");
        expect(session.currentIndex).toBe(1);
    });
});
