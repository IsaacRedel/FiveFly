import { describe, expect, it } from "vitest";
import { INITIAL_DATA, dataReducer, normalizeLibrary } from "../state/reducer";
import type { PlaylistSummary, SocialProfile, Track } from "../types";

const track = (videoId: string): Track => ({ videoId, title: videoId, thumbnail: `https://img/${videoId}`, duration: "3:00" });
const playlist: PlaylistSummary = { id: 1, name: "Mix", trackCount: 0, cover: "", visibility: "private" };

describe("dataReducer", () => {
    it("adds and removes favorites without duplicates", () => {
        let state = dataReducer(INITIAL_DATA, { type: "favoriteSet", track: track("a"), favorite: true });
        state = dataReducer(state, { type: "favoriteSet", track: track("a"), favorite: true });
        expect(state.library.favorites.map((item) => item.videoId)).toEqual(["a"]);

        state = dataReducer(state, { type: "favoriteSet", track: track("a"), favorite: false });
        expect(state.library.favorites).toEqual([]);
    });

    it("moves a played track to the top of the history", () => {
        let state = dataReducer(INITIAL_DATA, { type: "libraryPatched", patch: { history: [track("a"), track("b")] } });
        state = dataReducer(state, { type: "historyTouched", track: track("b") });

        expect(state.library.history.map((item) => item.videoId)).toEqual(["b", "a"]);
    });

    it("updates playlist counts and uses the first track artwork as cover", () => {
        let state = dataReducer(INITIAL_DATA, { type: "playlistAdded", playlist });
        state = dataReducer(state, { type: "playlistTrackAdded", id: 1, track: track("a") });
        state = dataReducer(state, { type: "playlistTrackAdded", id: 1, track: track("b") });

        expect(state.library.playlists[0].trackCount).toBe(2);
        expect(state.library.playlists[0].cover).toBe("https://img/a");

        state = dataReducer(state, { type: "playlistTrackRemoved", id: 1 });
        state = dataReducer(state, { type: "playlistTrackRemoved", id: 1 });
        state = dataReducer(state, { type: "playlistTrackRemoved", id: 1 });
        expect(state.library.playlists[0].trackCount).toBe(0);

        state = dataReducer(state, { type: "playlistRemoved", id: 1 });
        expect(state.library.playlists).toEqual([]);
    });

    it("keeps followed profiles in sync", () => {
        const profile: SocialProfile = {
            userId: 7, name: "DJ", bio: "", avatar: "", isPublic: true, showActivity: true,
            following: true, followerCount: 1, followingCount: 0, publicPlaylists: []
        };

        let state = dataReducer(INITIAL_DATA, { type: "followChanged", profile });
        expect(state.library.followingProfiles).toHaveLength(1);

        state = dataReducer(state, { type: "followChanged", profile: { ...profile, following: false } });
        expect(state.library.followingProfiles).toHaveLength(0);
    });

    it("normalizes partial server sessions", () => {
        const state = dataReducer(INITIAL_DATA, { type: "playbackSet", session: { status: "online" } as never });

        expect(state.playback.queue).toEqual([]);
        expect(state.playback.repeat).toBe("off");
        expect(state.playback.playback.nonce).toBe(0);
    });

    it("sets status to idle when nothing is loaded", () => {
        const state = dataReducer(INITIAL_DATA, { type: "playbackStatusSet", status: "online" });
        expect(state.playback.status).toBe("idle");
    });
});

describe("normalizeLibrary", () => {
    it("fills every list", () => {
        const library = normalizeLibrary({ favorites: [track("a")] });

        expect(library.favorites).toHaveLength(1);
        expect(library.playlists).toEqual([]);
        expect(library.smartPlaylists).toEqual([]);
    });
});
