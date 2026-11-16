import { fetchNui } from "./nui";
import type {
    AudioState,
    InitialState,
    OutputMode,
    PlaybackAction,
    PlaybackState,
    PlaylistVisibility,
    PlaylistSummary,
    RecommendationSection,
    RepeatMode,
    PlayerProfile,
    SharedSession,
    SocialProfile,
    SocialSearchResults,
    SmartPlaylist,
    Station,
    Track
} from "../types";

export const EMPTY_PLAYBACK: PlaybackState = {
    queue: [],
    currentTrack: null,
    currentIndex: null,
    status: "idle",
    repeat: "off",
    shuffle: false,
    playback: {
        position: 0,
        startedAt: 0,
        nonce: 0
    }
};

export const FALLBACK_INITIAL_STATE: InitialState = {
    profile: {
        userId: 0,
        name: "Player",
        bio: "",
        avatar: "",
        isPublic: true,
        showActivity: true,
        following: false,
        followerCount: 0,
        followingCount: 0,
        publicPlaylists: [],
        followingProfiles: []
    } satisfies PlayerProfile,
    playback: EMPTY_PLAYBACK,
    library: {
        favorites: [],
        playlists: [],
        history: [],
        stations: [],
        sharedSessions: [],
        friendsListening: [],
        followingProfiles: [],
        recommendations: [],
        smartPlaylists: []
    },
    audio: {
        output: "private",
        volume: 100,
        muted: false
    }
};

function getPreviewFallbacks() {
    return (window as any).__FIVEFY_PREVIEW__ || {};
}

function fallbackValue<T>(key: string, productionFallback: T): T {
    const previewFallback = getPreviewFallbacks()[key];
    return previewFallback === undefined ? productionFallback : previewFallback;
}

export function getInitialState() {
    return fetchNui<InitialState>("app.get-initial-state", {}, fallbackValue("initialState", FALLBACK_INITIAL_STATE));
}

export function getPlaybackState() {
    return fetchNui<PlaybackState>("playback.state.get", {}, fallbackValue("playback", FALLBACK_INITIAL_STATE.playback));
}

export function searchTracks(query: string) {
    const searchFallback = getPreviewFallbacks().searchTracks;
    const fallback = typeof searchFallback === "function" ? searchFallback(query) : { results: [] };

    return fetchNui<{ results: Track[] } & Partial<SocialSearchResults>>("music.search", { query }, fallback);
}

export function searchSocial(query: string) {
    return fetchNui<SocialSearchResults>("social.search", { query }, fallbackValue("socialSearch", {
        profiles: [],
        playlists: []
    }));
}

export function getSocialProfile(userId?: number) {
    const profileFallback = getPreviewFallbacks().socialProfile;
    const fallback = typeof profileFallback === "function" ? profileFallback(userId) : {
        profile: FALLBACK_INITIAL_STATE.profile
    };

    return fetchNui<{ profile: SocialProfile }>("social.profile.get", { userId }, fallback);
}

export function updateSocialProfile(profile: Partial<PlayerProfile>) {
    return fetchNui<{ profile: PlayerProfile }>("social.profile.update", profile, {
        profile: {
            ...FALLBACK_INITIAL_STATE.profile,
            ...profile
        }
    });
}

export function toggleFollow(userId: number) {
    return fetchNui<{ following: boolean }>("social.follow.toggle", { userId }, {
        following: true
    });
}

export function getStations() {
    return fetchNui<{ stations: Station[] }>("music.stations.get", {}, fallbackValue("stations", {
        stations: []
    }));
}

export function getRecommendations() {
    return fetchNui<{ recommendations: RecommendationSection[] }>("music.recommendations.get", {}, fallbackValue("recommendations", {
        recommendations: []
    }));
}

export function getSmartPlaylists() {
    return fetchNui<{ playlists: SmartPlaylist[] }>("library.smart-playlists.get", {}, fallbackValue("smartPlaylists", {
        playlists: []
    }));
}

export function clearHistory() {
    return fetchNui<{ cleared: boolean }>("library.history.clear", {}, {
        cleared: true
    });
}

export function getHistory() {
    return fetchNui<{ history: Track[] }>("library.history.get", {}, fallbackValue("history", {
        history: []
    }));
}

export function toggleFavorite(track: Track) {
    return fetchNui<{ favorite: boolean; track: Track }>("library.favorites.toggle", { track }, {
        favorite: true,
        track
    });
}

export function getPlaylistTracks(playlistId: number) {
    return fetchNui<{ tracks: Track[] }>("library.playlists.tracks.get", { playlistId }, fallbackValue("playlistTracks", {
        tracks: []
    }));
}

export function createPlaylist(name: string) {
    return fetchNui<{ playlist: PlaylistSummary }>("library.playlists.create", { name }, {
        playlist: {
            id: Date.now(),
            name,
            trackCount: 0,
            cover: "",
            shareCode: String(Date.now()).slice(-8),
            visibility: "private"
        }
    });
}

export function importPlaylist(shareCode: string) {
    return fetchNui<{ playlist: PlaylistSummary }>("library.playlists.import", { shareCode }, fallbackValue("importedPlaylist", {
        playlist: {
            id: Date.now(),
            name: "Imported playlist",
            trackCount: 0,
            cover: "",
            shareCode: String(Date.now()).slice(-8),
            visibility: "private"
        }
    }));
}

export function setPlaylistCover(playlistId: number, cover: string) {
    return fetchNui<{ updated: boolean }>("library.playlists.cover.set", { playlistId, cover }, {
        updated: true
    });
}

export function deletePlaylist(playlistId: number) {
    return fetchNui<{ deleted: boolean }>("library.playlists.delete", { playlistId }, {
        deleted: true
    });
}

export function addPlaylistTrack(playlistId: number, track: Track) {
    return fetchNui<{ added: boolean }>("library.playlists.tracks.add", { playlistId, track }, {
        added: true
    });
}

export function removePlaylistTrack(playlistId: number, videoId: string) {
    return fetchNui<{ removed: boolean }>("library.playlists.tracks.remove", { playlistId, videoId }, {
        removed: true
    });
}

/** Server default for Config.Playback.MaxQueueSize; longer lists are sent as a window around the track. */
const QUEUE_WINDOW = 50;

/** Plays `track` from `queue`, keeping the queue order. The server starts at `track` (startIndex breaks ties). */
export function playTrack(track: Track, queue: Track[] = []) {
    const index = queue.findIndex((queuedTrack) => queuedTrack.videoId === track.videoId);
    const list = index >= 0 ? queue : [track, ...queue];
    const position = Math.max(0, index);
    const windowStart = Math.max(0, Math.min(position - 5, list.length - QUEUE_WINDOW));
    const fullQueue = list.slice(windowStart, windowStart + QUEUE_WINDOW);
    const startIndex = position - windowStart + 1;
    const session: PlaybackState = {
        ...EMPTY_PLAYBACK,
        currentTrack: track,
        currentIndex: startIndex,
        queue: fullQueue,
        status: "online",
        playback: {
            position: 0,
            startedAt: Math.floor(Date.now() / 1000),
            nonce: Date.now()
        }
    };

    return fetchNui<{ session: PlaybackState }>("playback.play", { track, queue: fullQueue, startIndex }, { session });
}

export function transport(action: PlaybackAction, position?: number) {
    return fetchNui<{ session: PlaybackState }>("playback.transport", { action, position }, {
        session: EMPTY_PLAYBACK
    });
}

export function seekPlayback(position: number) {
    return fetchNui<{ session: PlaybackState }>("playback.seek", { position }, {
        session: {
            ...FALLBACK_INITIAL_STATE.playback,
            playback: {
                ...FALLBACK_INITIAL_STATE.playback.playback,
                position
            }
        }
    });
}

export function setPlaybackQueue(queue: Track[]) {
    const fallbackSession: PlaybackState = {
        ...FALLBACK_INITIAL_STATE.playback,
        queue
    };

    return fetchNui<{ session: PlaybackState }>("playback.queue.set", { queue }, {
        session: fallbackSession
    });
}

export function setPlaybackMode(mode: { shuffle?: boolean; repeat?: RepeatMode }) {
    const fallbackSession: PlaybackState = {
        ...FALLBACK_INITIAL_STATE.playback,
        shuffle: typeof mode.shuffle === "boolean" ? mode.shuffle : FALLBACK_INITIAL_STATE.playback.shuffle,
        repeat: mode.repeat || FALLBACK_INITIAL_STATE.playback.repeat
    };

    return fetchNui<{ session: PlaybackState }>("playback.mode.set", mode, {
        session: fallbackSession
    });
}

export function getSharedSessions() {
    return fetchNui<{ sessions: SharedSession[] }>("playback.sessions.get", {}, fallbackValue("sharedSessions", {
        sessions: []
    }));
}

export function setPlaylistVisibility(playlistId: number, visibility: PlaylistVisibility) {
    return fetchNui<{ visibility: PlaylistVisibility }>("library.playlists.visibility.set", { playlistId, visibility }, {
        visibility
    });
}

export function getFriendsListening() {
    return fetchNui<{ friends: SharedSession[] }>("playback.friends.get", {}, fallbackValue("friendsListening", {
        friends: []
    }));
}

export function joinSharedSession(source: number) {
    return fetchNui<{ session: PlaybackState }>("playback.sessions.join", { source }, {
        session: FALLBACK_INITIAL_STATE.playback
    });
}

export function setOutput(output: OutputMode) {
    return fetchNui<{ output: OutputMode }>("audio.output.set", { output }, { output });
}

export function setVolume(value: number) {
    return fetchNui<{ value: number }>("audio.volume.set", { value }, { value });
}

export function setMuted(muted: boolean) {
    return fetchNui<{ muted: boolean }>("audio.mute.set", { muted }, { muted });
}

export function normalizeAudio(audio?: Partial<AudioState>): AudioState {
    return {
        output: audio?.output || FALLBACK_INITIAL_STATE.audio.output,
        volume: typeof audio?.volume === "number" ? audio.volume : FALLBACK_INITIAL_STATE.audio.volume,
        muted: audio?.muted === true
    };
}
