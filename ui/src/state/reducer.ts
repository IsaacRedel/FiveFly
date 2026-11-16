import { EMPTY_PLAYBACK, FALLBACK_INITIAL_STATE, normalizeAudio } from "../bridge/api";
import type { AudioState, InitialState, LibraryState, PlaybackState, PlayerProfile, PlaylistSummary, SocialProfile, Track } from "../types";

export type DataState = {
    profile: PlayerProfile;
    playback: PlaybackState;
    library: LibraryState;
    audio: AudioState;
};

export type DataAction =
    | { type: "initialLoaded"; state: InitialState }
    | { type: "playbackSet"; session: PlaybackState }
    | { type: "playbackStatusSet"; status: PlaybackState["status"] }
    | { type: "audioPatched"; audio: Partial<AudioState> }
    | { type: "libraryPatched"; patch: Partial<LibraryState> }
    | { type: "profileSet"; profile: PlayerProfile }
    | { type: "historyTouched"; track: Track }
    | { type: "favoriteSet"; track: Track; favorite: boolean }
    | { type: "playlistAdded"; playlist: PlaylistSummary }
    | { type: "playlistPatched"; id: number; patch: Partial<PlaylistSummary> }
    | { type: "playlistRemoved"; id: number }
    | { type: "playlistTrackAdded"; id: number; track: Track }
    | { type: "playlistTrackRemoved"; id: number }
    | { type: "followChanged"; profile: SocialProfile };

export const INITIAL_DATA: DataState = {
    profile: FALLBACK_INITIAL_STATE.profile,
    playback: FALLBACK_INITIAL_STATE.playback,
    library: FALLBACK_INITIAL_STATE.library,
    audio: FALLBACK_INITIAL_STATE.audio
};

/** Fills missing library lists so views can always map over them. */
export function normalizeLibrary(library?: Partial<LibraryState>): LibraryState {
    const fallback = FALLBACK_INITIAL_STATE.library;

    return {
        favorites: library?.favorites || fallback.favorites,
        playlists: library?.playlists || fallback.playlists,
        history: library?.history || fallback.history,
        stations: library?.stations || fallback.stations,
        sharedSessions: library?.sharedSessions || fallback.sharedSessions,
        friendsListening: library?.friendsListening || fallback.friendsListening,
        followingProfiles: library?.followingProfiles || fallback.followingProfiles,
        recommendations: library?.recommendations || fallback.recommendations,
        smartPlaylists: library?.smartPlaylists || fallback.smartPlaylists
    };
}

function normalizePlayback(session?: Partial<PlaybackState> | null): PlaybackState {
    return {
        ...EMPTY_PLAYBACK,
        ...(session || {}),
        queue: session?.queue || [],
        currentTrack: session?.currentTrack || null,
        repeat: session?.repeat || "off",
        shuffle: session?.shuffle === true,
        playback: { ...EMPTY_PLAYBACK.playback, ...(session?.playback || {}) }
    };
}

function mapPlaylists(state: DataState, id: number, update: (playlist: PlaylistSummary) => PlaylistSummary): DataState {
    return {
        ...state,
        library: {
            ...state.library,
            playlists: state.library.playlists.map((playlist) => (playlist.id === id ? update(playlist) : playlist))
        }
    };
}

export function dataReducer(state: DataState, action: DataAction): DataState {
    switch (action.type) {
        case "initialLoaded":
            return {
                profile: action.state.profile || FALLBACK_INITIAL_STATE.profile,
                playback: normalizePlayback(action.state.playback),
                library: normalizeLibrary(action.state.library),
                audio: normalizeAudio(action.state.audio)
            };

        case "playbackSet":
            return { ...state, playback: normalizePlayback(action.session) };

        case "playbackStatusSet":
            return {
                ...state,
                playback: { ...state.playback, status: state.playback.currentTrack ? action.status : "idle" }
            };

        case "audioPatched":
            return { ...state, audio: normalizeAudio({ ...state.audio, ...action.audio }) };

        case "libraryPatched":
            return { ...state, library: { ...state.library, ...action.patch } };

        case "profileSet":
            return {
                ...state,
                profile: action.profile,
                library: {
                    ...state.library,
                    followingProfiles: action.profile.followingProfiles || state.library.followingProfiles
                }
            };

        case "historyTouched":
            return {
                ...state,
                library: {
                    ...state.library,
                    history: [action.track, ...state.library.history.filter((item) => item.videoId !== action.track.videoId)]
                }
            };

        case "favoriteSet": {
            const others = state.library.favorites.filter((favorite) => favorite.videoId !== action.track.videoId);

            return {
                ...state,
                library: { ...state.library, favorites: action.favorite ? [action.track, ...others] : others }
            };
        }

        case "playlistAdded":
            return {
                ...state,
                library: {
                    ...state.library,
                    playlists: [action.playlist, ...state.library.playlists.filter((item) => item.id !== action.playlist.id)]
                }
            };

        case "playlistPatched":
            return mapPlaylists(state, action.id, (playlist) => ({ ...playlist, ...action.patch }));

        case "playlistRemoved":
            return {
                ...state,
                library: { ...state.library, playlists: state.library.playlists.filter((playlist) => playlist.id !== action.id) }
            };

        case "playlistTrackAdded":
            return mapPlaylists(state, action.id, (playlist) => ({
                ...playlist,
                trackCount: playlist.trackCount + 1,
                cover: playlist.cover || action.track.thumbnail
            }));

        case "playlistTrackRemoved":
            return mapPlaylists(state, action.id, (playlist) => ({ ...playlist, trackCount: Math.max(0, playlist.trackCount - 1) }));

        case "followChanged": {
            const others = state.library.followingProfiles.filter((item) => item.userId !== action.profile.userId);

            return {
                ...state,
                library: {
                    ...state.library,
                    followingProfiles: action.profile.following ? [action.profile, ...others] : others
                }
            };
        }

        default:
            return state;
    }
}
