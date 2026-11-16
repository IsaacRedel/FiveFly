import type { InitialState, PlaybackState, PlaylistSummary, RecommendationSection, SharedSession, SmartPlaylist, SocialProfile, Station, Track } from "../types";

export const PREVIEW_TRACKS: Track[] = [
    {
        videoId: "sample-vinyl",
        title: "Vinyl Scratch",
        author: "DJ Retro",
        duration: "5:01",
        thumbnail: "https://images.unsplash.com/photo-1687359927083-cdaaa019accf?w=500&q=80"
    },
    {
        videoId: "sample-neon",
        title: "Neon Dreams",
        author: "Vice City",
        duration: "4:12",
        thumbnail: "https://images.unsplash.com/photo-1608347539243-b592b14332d8?w=500&q=80"
    },
    {
        videoId: "sample-street",
        title: "Street Echo",
        author: "Ghost Dog",
        duration: "2:58",
        thumbnail: "https://images.unsplash.com/photo-1572223501266-c5f128d0586e?w=500&q=80"
    },
    {
        videoId: "sample-lowrider",
        title: "Lowrider Bounce",
        author: "Grove St. Fam",
        duration: "3:45",
        thumbnail: "https://images.unsplash.com/photo-1639445837038-4493d8715829?w=500&q=80"
    }
];

const previewPlaylists: PlaylistSummary[] = [
    { id: 1, name: "Roleplay Vibes", trackCount: 42, cover: PREVIEW_TRACKS[0].thumbnail, shareCode: "FIVEFLY01", visibility: "public", ownerUserId: 0, ownerName: "Alex Rivera" },
    { id: 2, name: "Late Night Drive", trackCount: 15, cover: PREVIEW_TRACKS[1].thumbnail, shareCode: "DRIVE001", visibility: "private", ownerUserId: 0, ownerName: "Alex Rivera" },
    { id: 3, name: "Fugas", trackCount: 8, cover: PREVIEW_TRACKS[2].thumbnail, shareCode: "FUGAS001", visibility: "private", ownerUserId: 0, ownerName: "Alex Rivera" }
];

const previewStations: Station[] = [
    {
        id: "night-drive-fm",
        name: "Night Drive FM",
        description: "24/7 synthwave for late drives.",
        cover: "https://images.unsplash.com/photo-1507874457470-272b3c8d8ee2?w=500&q=80",
        tracks: [
            {
                ...PREVIEW_TRACKS[0],
                videoId: "night-drive-stream",
                title: "Night Drive FM",
                author: "Live radio",
                streamUrl: "https://example.com/stream.mp3"
            },
            PREVIEW_TRACKS[1],
            PREVIEW_TRACKS[2]
        ]
    },
    {
        id: "rua",
        name: "Street",
        description: "Urban beats for street roleplay.",
        cover: "https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=500&q=80",
        tracks: [PREVIEW_TRACKS[2], PREVIEW_TRACKS[3]]
    },
    {
        id: "drive",
        name: "Drive",
        description: "Night-time driving mix.",
        cover: "https://images.unsplash.com/photo-1493246507139-91e8fad9978e?w=500&q=80",
        tracks: [PREVIEW_TRACKS[1], PREVIEW_TRACKS[0], PREVIEW_TRACKS[3]]
    }
];

const previewSharedSessions: SharedSession[] = [
    {
        source: 7,
        host: "DJ Retro",
        output: "prop",
        currentTrack: PREVIEW_TRACKS[0],
        queueCount: 4
    }
];

const previewRecommendations: RecommendationSection[] = [
    { id: "history", title: "Based on your history", tracks: PREVIEW_TRACKS.slice(0, 3) },
    { id: "time", title: "For this time of day", tracks: PREVIEW_TRACKS.slice(1, 4) },
    { id: "artist", title: "Based on an artist", tracks: [PREVIEW_TRACKS[0], PREVIEW_TRACKS[3]] }
];

const previewSmartPlaylists: SmartPlaylist[] = [
    { id: "most-played", title: "Most played", description: "", tracks: PREVIEW_TRACKS.slice(0, 3) },
    { id: "most-skipped", title: "Most skipped", description: "", tracks: PREVIEW_TRACKS.slice(1, 3) },
    { id: "most-liked", title: "Most liked", description: "", tracks: PREVIEW_TRACKS.slice(0, 4) }
];

const previewSocialProfiles: SocialProfile[] = [
    {
        userId: 7,
        name: "DJ Retro",
        bio: "Late-night roleplay setlists.",
        avatar: PREVIEW_TRACKS[0].thumbnail,
        isPublic: true,
        showActivity: true,
        following: true,
        followerCount: 12,
        followingCount: 4,
        publicPlaylists: [previewPlaylists[0]]
    }
];

const previewPlayback: PlaybackState = {
    queue: PREVIEW_TRACKS,
    currentTrack: PREVIEW_TRACKS[0],
    currentIndex: 1,
    status: "online",
    repeat: "off",
    shuffle: false,
    playback: {
        position: 74,
        startedAt: 0,
        nonce: 1
    }
};

export const PREVIEW_INITIAL_STATE: InitialState = {
    profile: {
        userId: 0,
        name: "Alex Rivera",
        bio: "",
        avatar: "",
        isPublic: true,
        showActivity: true,
        following: false,
        followerCount: 0,
        followingCount: 0,
        publicPlaylists: [previewPlaylists[0]],
        followingProfiles: previewSocialProfiles
    },
    playback: previewPlayback,
    library: {
        favorites: [PREVIEW_TRACKS[0], PREVIEW_TRACKS[2]],
        playlists: previewPlaylists,
        history: PREVIEW_TRACKS.slice(1),
        stations: previewStations,
        sharedSessions: previewSharedSessions,
        friendsListening: previewSharedSessions,
        followingProfiles: previewSocialProfiles,
        recommendations: previewRecommendations,
        smartPlaylists: previewSmartPlaylists
    },
    audio: {
        output: "private",
        volume: 100,
        muted: false
    }
};

export const PREVIEW_API_FALLBACKS = {
    initialState: PREVIEW_INITIAL_STATE,
    playback: previewPlayback,
    searchTracks(query: string) {
        const value = query.toLowerCase();
        return {
            results: PREVIEW_TRACKS.filter((track) => `${track.title} ${track.author || ""}`.toLowerCase().includes(value))
        };
    },
    socialSearch: {
        profiles: previewSocialProfiles,
        playlists: previewPlaylists.filter((playlist) => playlist.visibility === "public")
    },
    socialProfile(userId?: number) {
        return {
            profile: userId && userId !== 0 ? previewSocialProfiles[0] : PREVIEW_INITIAL_STATE.profile
        };
    },
    stations: { stations: previewStations },
    history: { history: PREVIEW_TRACKS.slice(1) },
    recommendations: { recommendations: previewRecommendations },
    smartPlaylists: { playlists: previewSmartPlaylists },
    playlistTracks: { tracks: PREVIEW_TRACKS },
    importedPlaylist: {
        playlist: {
            id: Date.now(),
            name: "Imported playlist",
            trackCount: PREVIEW_TRACKS.length,
            cover: PREVIEW_TRACKS[0].thumbnail,
            shareCode: String(Date.now()).slice(-8),
            visibility: "private"
        }
    },
    sharedSessions: { sessions: previewSharedSessions },
    friendsListening: { friends: previewSharedSessions }
};
