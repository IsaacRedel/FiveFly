import { createContext, useCallback, useContext, useEffect, useMemo, useReducer, useRef, useState, type ReactNode } from "react";
import * as api from "../bridge/api";
import { copyTextToClipboard, getUiOrigin, selectLbPhoneGalleryPhoto, type UiOrigin } from "../bridge/nui";
import { I18nContext, createTranslator, normalizeLocale, translateError, type Locale } from "../i18n";
import type { MessageKey } from "../i18n/en";
import { durationToSeconds, progressFromSession, resolveLiveProgress, type Progress } from "../lib/time";
import { isFavorite, moveItem } from "../lib/tracks";
import type {
    AppView,
    LibraryTab,
    OutputMode,
    PlaybackState,
    PlayerProfile,
    PlaylistSummary,
    PlaylistVisibility,
    RepeatMode,
    SocialProfile,
    SocialSearchResults,
    Track
} from "../types";
import { INITIAL_DATA, dataReducer, type DataState } from "./reducer";

export type Sheet =
    | { type: "audio" }
    | { type: "settings" }
    | { type: "profileEdit" }
    | { type: "queue" }
    | { type: "trackActions"; track: Track }
    | { type: "playlistSelect"; track: Track }
    | { type: "playlistCreate" }
    | { type: "playlistImport" }
    | { type: "playlistCover" };

const EMPTY_SOCIAL: SocialSearchResults = { profiles: [], playlists: [] };

function useFiveFlyStore(origin: UiOrigin) {
    const [data, dispatch] = useReducer(dataReducer, INITIAL_DATA);
    const [locale, setLocale] = useState<Locale>(normalizeLocale(new URLSearchParams(window.location.search).get("lang") || navigator.language));
    const [appName, setAppName] = useState("FiveFly");
    const t = useMemo(() => createTranslator(locale, appName), [locale, appName]);

    const [view, setView] = useState<AppView>("home");
    const [previousView, setPreviousView] = useState<AppView>("home");
    const [libraryTab, setLibraryTab] = useState<LibraryTab>("playlists");
    const [selectedPlaylistId, setSelectedPlaylistId] = useState<number | null>(null);
    const [selectedPlaylistTracks, setSelectedPlaylistTracks] = useState<Track[]>([]);
    const [selectedProfile, setSelectedProfile] = useState<SocialProfile | null>(null);

    const [query, setQuery] = useState("");
    const [searchResults, setSearchResults] = useState<Track[]>([]);
    const [socialResults, setSocialResults] = useState<SocialSearchResults>(EMPTY_SOCIAL);
    const [isSearching, setIsSearching] = useState(false);

    const [sheet, setSheet] = useState<Sheet | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [notice, setNotice] = useState<string | null>(null);
    const [playbackBusy, setPlaybackBusy] = useState(false);
    const [progress, setProgress] = useState<Progress>({ position: 0, duration: 0, updatedAt: Date.now() });
    const [clock, setClock] = useState(Date.now());

    const { playback, library, profile, audio } = data;
    const currentTrack = playback.currentTrack;
    const isPlaying = playback.status === "online";
    const liveProgress = resolveLiveProgress(progress, isPlaying, currentTrack, clock);
    const selectedPlaylist = library.playlists.find((playlist) => playlist.id === selectedPlaylistId) || null;

    // Latest values for event listeners registered once.
    const latest = useRef({ currentTrack, isPlaying });
    latest.current = { currentTrack, isPlaying };

    const fail = useCallback((code?: string) => setError(code || "unknown"), []);
    const showNotice = useCallback((key: MessageKey) => setNotice(t(key)), [t]);

    const applySession = useCallback((session: PlaybackState) => {
        dispatch({ type: "playbackSet", session });
        setProgress(progressFromSession(session));
        setClock(Date.now());
    }, []);

    const loadInitialState = useCallback((attempt = 0): Promise<void> => {
        return api.getInitialState().then((response) => {
            if (response.error === "rate_limited" && attempt < 2) {
                // Reloads can follow each other quickly (phone + panel); retry quietly.
                window.setTimeout(() => loadInitialState(attempt + 1), 400);
                return;
            }

            if (!response.ok || !response.data) {
                fail(response.error);
                return;
            }

            if (response.data.locale) {
                setLocale(normalizeLocale(response.data.locale));
            }

            if (response.data.appName) {
                setAppName(response.data.appName);
            }

            dispatch({ type: "initialLoaded", state: response.data });
            setProgress(progressFromSession(response.data.playback));
        });
    }, [fail]);

    useEffect(() => {
        loadInitialState();
    }, [loadInitialState]);

    // Advance the progress bar while playing.
    useEffect(() => {
        if (!isPlaying || !currentTrack) return;

        const timer = window.setInterval(() => setClock(Date.now()), 500);
        return () => window.clearInterval(timer);
    }, [isPlaying, currentTrack?.videoId]);

    // State pushed by the client (see client/main.lua FiveFly.SendUiMessage).
    useEffect(() => {
        let reloadTimer = 0;

        const onMessage = (event: MessageEvent) => {
            const message = event.data || {};
            const target = message.target;

            if (target && target !== "ui" && target !== "panel") return;

            if (message.action === "audio.state") {
                dispatch({ type: "audioPatched", audio: message.data || {} });
            } else if (message.action === "playback.state") {
                applySession(message.data as PlaybackState);
            } else if (message.action === "playback.error") {
                fail("engine_error");
            } else if (message.action === "library.changed" && message.data?.origin !== getUiOrigin()) {
                window.clearTimeout(reloadTimer);
                reloadTimer = window.setTimeout(() => loadInitialState(), 400);
            } else if (message.action === "playback.progress") {
                const incoming = message.data || {};
                const { currentTrack: track, isPlaying: playing } = latest.current;
                const duration = Number(incoming.duration) || durationToSeconds(track?.duration);
                const position = Number(incoming.position) || 0;
                const videoId = incoming.videoId ? String(incoming.videoId) : "";

                setProgress((current) => {
                    const now = Date.now();
                    const live = resolveLiveProgress(current, playing, track, now);
                    const sameTrack = !videoId || videoId === track?.videoId;
                    // The engine reports 0 while a new video buffers; keep the local estimate meanwhile.
                    const keepLocal = sameTrack && playing && position <= 0 && live.position > 0.8;

                    return { position: keepLocal ? live.position : position, duration, updatedAt: now };
                });
            }
        };

        window.addEventListener("message", onMessage);
        return () => {
            window.removeEventListener("message", onMessage);
            window.clearTimeout(reloadTimer);
        };
    }, [applySession, fail, loadInitialState]);

    // Debounced search across tracks and social results.
    useEffect(() => {
        const value = query.trim();

        if (!value) {
            setSearchResults([]);
            setSocialResults(EMPTY_SOCIAL);
            setIsSearching(false);
            return;
        }

        setIsSearching(true);
        let cancelled = false;
        const timer = window.setTimeout(() => {
            Promise.all([api.searchTracks(value), api.searchSocial(value)]).then(([music, social]) => {
                if (cancelled) return;

                if (!music.ok && music.error) fail(music.error);
                setSearchResults(music.ok && music.data ? music.data.results : []);
                setSocialResults(social.ok && social.data ? social.data : EMPTY_SOCIAL);
                setIsSearching(false);
            });
        }, 350);

        return () => {
            cancelled = true;
            window.clearTimeout(timer);
        };
    }, [query, fail]);

    useEffect(() => {
        if (!notice) return;

        const timer = window.setTimeout(() => setNotice(null), 2200);
        return () => window.clearTimeout(timer);
    }, [notice]);

    useEffect(() => {
        if (!error) return;

        const timer = window.setTimeout(() => setError(null), 4000);
        return () => window.clearTimeout(timer);
    }, [error]);

    // ---------------------------------------------------------------------------------------------
    // Navigation
    // ---------------------------------------------------------------------------------------------

    function openView(nextView: AppView) {
        setPreviousView(view);
        setView(nextView);
    }

    function goBack(fallback: AppView = "home") {
        setView(previousView === view ? fallback : previousView);
    }

    function openPlaylist(playlistId: number) {
        setSelectedPlaylistId(playlistId);
        setSelectedPlaylistTracks([]);
        openView("playlist");

        api.getPlaylistTracks(playlistId).then((response) => {
            if (!response.ok || !response.data) {
                fail(response.error);
                return;
            }

            setSelectedPlaylistTracks(response.data.tracks);
        });
    }

    function openProfile(userId?: number) {
        api.getSocialProfile(userId).then((response) => {
            if (!response.ok || !response.data?.profile) {
                fail(response.error);
                return;
            }

            setSelectedProfile(response.data.profile);
            openView("profile");
        });
    }

    // ---------------------------------------------------------------------------------------------
    // Playback
    // ---------------------------------------------------------------------------------------------

    function refreshHistory(track?: Track | null) {
        if (track) dispatch({ type: "historyTouched", track });

        api.getHistory().then((response) => {
            if (response.ok && response.data) {
                dispatch({ type: "libraryPatched", patch: { history: response.data.history } });
            }
        });
    }

    function play(track: Track, queue: Track[] = []) {
        setPlaybackBusy(true);

        api.playTrack(track, queue).then((response) => {
            if (!response.ok || !response.data) {
                fail(response.error);
                return;
            }

            applySession(response.data.session);
            refreshHistory(response.data.session.currentTrack || track);
            showNotice("notice.playing");
        }).finally(() => setPlaybackBusy(false));
    }

    function runTransport(action: "pause" | "resume" | "next" | "prev" | "stop") {
        setPlaybackBusy(true);
        const position = resolveLiveProgress(progress, isPlaying, currentTrack).position;

        api.transport(action, position).then((response) => {
            if (response.ok && response.data) {
                dispatch({ type: "playbackSet", session: response.data.session });

                if (action === "pause") {
                    setProgress({ ...resolveLiveProgress(progress, isPlaying, currentTrack), updatedAt: Date.now() });
                } else {
                    setProgress(progressFromSession(response.data.session));
                }

                setClock(Date.now());

                if (action === "next" || action === "prev") {
                    refreshHistory(response.data.session.currentTrack);
                }

                return;
            }

            fail(response.error);
        }).finally(() => setPlaybackBusy(false));
    }

    function togglePlay() {
        runTransport(isPlaying ? "pause" : "resume");
    }

    function seekTo(position: number) {
        setPlaybackBusy(true);

        api.seekPlayback(position).then((response) => {
            if (!response.ok || !response.data?.session) {
                fail(response.error);
                return;
            }

            dispatch({ type: "playbackSet", session: response.data.session });
            setProgress((current) => ({ ...current, position, updatedAt: Date.now() }));
            setClock(Date.now());
        }).finally(() => setPlaybackBusy(false));
    }

    function updateQueue(queue: Track[]) {
        api.setPlaybackQueue(queue).then((response) => {
            if (!response.ok || !response.data?.session) {
                fail(response.error);
                return;
            }

            dispatch({ type: "playbackSet", session: response.data.session });
            showNotice("notice.queueUpdated");
        });
    }

    function removeFromQueue(index: number) {
        const currentIndex = Math.max(0, (playback.currentIndex || 1) - 1);

        if (index > currentIndex) {
            updateQueue(playback.queue.filter((_, itemIndex) => itemIndex !== index));
        }
    }

    function moveQueueItem(index: number, direction: -1 | 1) {
        const currentIndex = Math.max(0, (playback.currentIndex || 1) - 1);

        if (index === currentIndex) return;

        const next = moveItem(playback.queue, index, direction);

        if (next !== playback.queue) updateQueue(next);
    }

    function updatePlaybackMode(mode: { shuffle?: boolean; repeat?: RepeatMode }) {
        api.setPlaybackMode(mode).then((response) => {
            if (!response.ok || !response.data?.session) {
                fail(response.error);
                return;
            }

            dispatch({ type: "playbackSet", session: response.data.session });
        });
    }

    function toggleShuffle() {
        updatePlaybackMode({ shuffle: playback.shuffle !== true });
    }

    function cycleRepeat() {
        const order: RepeatMode[] = ["off", "all", "one"];
        updatePlaybackMode({ repeat: order[(order.indexOf(playback.repeat || "off") + 1) % order.length] });
    }

    function joinSession(source: number) {
        setPlaybackBusy(true);
        showNotice("notice.joiningSession");

        api.joinSharedSession(source).then((response) => {
            if (!response.ok || !response.data?.session) {
                fail(response.error);
                return;
            }

            applySession(response.data.session);
            openView("player");
        }).finally(() => setPlaybackBusy(false));
    }

    function refreshSessions() {
        api.getSharedSessions().then((response) => {
            if (response.ok && response.data) {
                dispatch({ type: "libraryPatched", patch: { sharedSessions: response.data.sessions } });
            } else {
                fail(response.error);
            }
        });

        api.getFriendsListening().then((response) => {
            if (response.ok && response.data) {
                dispatch({ type: "libraryPatched", patch: { friendsListening: response.data.friends } });
            }
        });
    }

    function refreshDiscovery() {
        Promise.all([api.getRecommendations(), api.getSmartPlaylists()]).then(([recommendations, smart]) => {
            if (!recommendations.ok || !smart.ok) {
                fail(recommendations.error || smart.error);
                return;
            }

            dispatch({
                type: "libraryPatched",
                patch: {
                    recommendations: recommendations.data?.recommendations || [],
                    smartPlaylists: smart.data?.playlists || []
                }
            });
            showNotice("notice.suggestionsUpdated");
        });
    }

    // ---------------------------------------------------------------------------------------------
    // Audio (local to the client)
    // ---------------------------------------------------------------------------------------------

    function chooseOutput(output: OutputMode) {
        api.setOutput(output).then((response) => {
            if (!response.ok || !response.data) {
                fail(response.error || "output_failed");
                return;
            }

            dispatch({ type: "audioPatched", audio: { output: response.data.output } });
            setSheet(null);
            showNotice("notice.outputChanged");
        });
    }

    function changeVolume(value: number) {
        dispatch({ type: "audioPatched", audio: { volume: value } });
        api.setVolume(value);
    }

    function toggleMute() {
        const muted = !audio.muted;
        dispatch({ type: "audioPatched", audio: { muted } });
        api.setMuted(muted);
    }

    // ---------------------------------------------------------------------------------------------
    // Library
    // ---------------------------------------------------------------------------------------------

    function toggleTrackFavorite(track: Track) {
        const wasFavorite = isFavorite(track, library.favorites);
        dispatch({ type: "favoriteSet", track, favorite: !wasFavorite });

        api.toggleFavorite(track).then((response) => {
            if (!response.ok || !response.data) {
                dispatch({ type: "favoriteSet", track, favorite: wasFavorite });
                fail(response.error);
                return;
            }

            dispatch({ type: "favoriteSet", track, favorite: response.data.favorite });
            showNotice(response.data.favorite ? "notice.liked" : "notice.unliked");
        });
    }

    function openTrackActions(track: Track) {
        setSheet({ type: "trackActions", track });
    }

    function addTrackToPlaylist(track: Track, playlistId: number) {
        api.addPlaylistTrack(playlistId, track).then((response) => {
            if (!response.ok || !response.data?.added) {
                fail(response.error);
                return;
            }

            if (selectedPlaylistId === playlistId) {
                setSelectedPlaylistTracks((current) => (current.some((item) => item.videoId === track.videoId) ? current : [...current, track]));
            }

            dispatch({ type: "playlistTrackAdded", id: playlistId, track });
            showNotice("notice.addedToPlaylist");
            setSheet(null);
        });
    }

    function removeTrackFromPlaylist(track: Track) {
        if (!selectedPlaylistId) return;

        const playlistId = selectedPlaylistId;

        api.removePlaylistTrack(playlistId, track.videoId).then((response) => {
            if (!response.ok || !response.data?.removed) {
                fail(response.error);
                return;
            }

            setSelectedPlaylistTracks((current) => current.filter((item) => item.videoId !== track.videoId));
            dispatch({ type: "playlistTrackRemoved", id: playlistId });
            showNotice("notice.removedFromPlaylist");
            setSheet(null);
        });
    }

    function createPlaylist(name: string) {
        api.createPlaylist(name).then((response) => {
            if (!response.ok || !response.data?.playlist) {
                fail(response.error);
                return;
            }

            dispatch({ type: "playlistAdded", playlist: response.data.playlist });
            showNotice("notice.playlistCreated");
            setSheet(null);
        });
    }

    function importPlaylist(shareCode: string) {
        api.importPlaylist(shareCode).then((response) => {
            if (!response.ok || !response.data?.playlist) {
                fail(response.error);
                return;
            }

            dispatch({ type: "playlistAdded", playlist: response.data.playlist });
            showNotice("notice.playlistImported");
            setSheet(null);
        });
    }

    function setPlaylistCover(cover: string) {
        if (!selectedPlaylistId || !cover.trim()) return;

        const playlistId = selectedPlaylistId;

        api.setPlaylistCover(playlistId, cover.trim()).then((response) => {
            if (!response.ok || !response.data?.updated) {
                fail(response.error);
                return;
            }

            const resolved = (response.data as { cover?: string }).cover || cover.trim();
            dispatch({ type: "playlistPatched", id: playlistId, patch: { cover: resolved } });
            showNotice("notice.coverUpdated");
            setSheet(null);
        });
    }

    function setPlaylistVisibility(playlist: PlaylistSummary, visibility: PlaylistVisibility) {
        api.setPlaylistVisibility(playlist.id, visibility).then((response) => {
            if (!response.ok || !response.data) {
                fail(response.error);
                return;
            }

            dispatch({ type: "playlistPatched", id: playlist.id, patch: { visibility: response.data.visibility } });
            showNotice(response.data.visibility === "public" ? "notice.playlistPublic" : "notice.playlistPrivate");
        });
    }

    function deleteSelectedPlaylist() {
        if (!selectedPlaylist) return;

        const playlistId = selectedPlaylist.id;

        api.deletePlaylist(playlistId).then((response) => {
            if (!response.ok || !response.data?.deleted) {
                fail(response.error);
                return;
            }

            dispatch({ type: "playlistRemoved", id: playlistId });
            setSelectedPlaylistId(null);
            setSelectedPlaylistTracks([]);
            setView("library");
            showNotice("notice.playlistDeleted");
        });
    }

    function copyPlaylistCode(code: string) {
        copyTextToClipboard(code).then((copied) => showNotice(copied ? "notice.codeCopied" : "notice.copyFailed"));
    }

    function clearHistory() {
        api.clearHistory().then((response) => {
            if (!response.ok || !response.data?.cleared) {
                fail(response.error);
                return;
            }

            dispatch({ type: "libraryPatched", patch: { history: [] } });
            setSheet(null);
            showNotice("notice.historyCleared");
        });
    }

    // ---------------------------------------------------------------------------------------------
    // Social
    // ---------------------------------------------------------------------------------------------

    function updateProfile(nextProfile: Partial<PlayerProfile>) {
        api.updateSocialProfile(nextProfile).then((response) => {
            if (!response.ok || !response.data?.profile) {
                fail(response.error);
                return;
            }

            dispatch({ type: "profileSet", profile: response.data.profile });
            setSelectedProfile(response.data.profile);
            showNotice("notice.profileUpdated");
            setSheet(null);
        });
    }

    function toggleFollow(target: SocialProfile) {
        api.toggleFollow(target.userId).then((response) => {
            if (!response.ok || !response.data) {
                fail(response.error);
                return;
            }

            const following = response.data.following;
            const next = { ...target, following, followerCount: Math.max(0, target.followerCount + (following ? 1 : -1)) };

            setSelectedProfile(next);
            setSocialResults((current) => ({
                ...current,
                profiles: current.profiles.map((item) => (item.userId === next.userId ? next : item))
            }));
            dispatch({ type: "followChanged", profile: next });
            showNotice(following ? "notice.followed" : "notice.unfollowed");
        });
    }

    return {
        origin,
        t,
        locale,
        appName,
        data: data as DataState,
        currentTrack,
        isPlaying,
        liveProgress,
        playbackBusy,
        view,
        libraryTab,
        selectedPlaylist,
        selectedPlaylistTracks,
        activeProfile: (selectedProfile || profile) as SocialProfile,
        query,
        searchResults,
        socialResults,
        isSearching,
        sheet,
        error: error ? translateError(t, error) : null,
        notice,
        actions: {
            reload: () => { loadInitialState(); },
            openView,
            goBack,
            setLibraryTab,
            openPlaylist,
            openProfile,
            setQuery,
            setSheet,
            dismissError: () => setError(null),
            dismissNotice: () => setNotice(null),
            play,
            runTransport,
            togglePlay,
            seekTo,
            removeFromQueue,
            moveQueueItem,
            toggleShuffle,
            cycleRepeat,
            joinSession,
            refreshSessions,
            refreshDiscovery,
            chooseOutput,
            changeVolume,
            toggleMute,
            toggleTrackFavorite,
            openTrackActions,
            addTrackToPlaylist,
            removeTrackFromPlaylist,
            createPlaylist,
            importPlaylist,
            setPlaylistCover,
            setPlaylistVisibility,
            deleteSelectedPlaylist,
            copyPlaylistCode,
            clearHistory,
            updateProfile,
            toggleFollow,
            chooseAvatarFromGallery: selectLbPhoneGalleryPhoto
        }
    };
}

export type FiveFlyStore = ReturnType<typeof useFiveFlyStore>;

const StoreContext = createContext<FiveFlyStore | null>(null);

export function FiveFlyProvider({ origin, children }: { origin: UiOrigin; children: ReactNode }) {
    const store = useFiveFlyStore(origin);

    return (
        <StoreContext.Provider value={store}>
            <I18nContext.Provider value={store.t}>{children}</I18nContext.Provider>
        </StoreContext.Provider>
    );
}

export function useFiveFly() {
    const store = useContext(StoreContext);

    if (!store) {
        throw new Error("useFiveFly must be used inside FiveFlyProvider");
    }

    return store;
}
