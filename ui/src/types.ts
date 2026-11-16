export type NuiResponse<T> = {
    ok: boolean;
    data?: T;
    error?: string;
};

export type Track = {
    videoId: string;
    streamUrl?: string;
    youtubeUrl?: string;
    title: string;
    thumbnail: string;
    duration: string;
    author?: string;
};

export type OutputMode = "prop" | "vehicle" | "private" | "off";

export type PlaybackStatus = "idle" | "online" | "paused";

export type RepeatMode = "off" | "all" | "one";

export type PlaylistVisibility = "private" | "public";

export type PlaybackState = {
    queue: Track[];
    currentTrack: Track | null;
    currentIndex: number | null;
    status: PlaybackStatus;
    repeat: RepeatMode;
    shuffle: boolean;
    playback: {
        position: number;
        startedAt: number;
        nonce: number;
    };
};

export type PlaylistSummary = {
    id: number;
    name: string;
    trackCount: number;
    cover?: string;
    shareCode?: string;
    visibility: PlaylistVisibility;
    ownerUserId?: number;
    ownerName?: string;
};

export type Station = {
    id: string;
    name: string;
    description: string;
    cover: string;
    tracks: Track[];
};

export type SharedSession = {
    source: number;
    userId?: number;
    host: string;
    output: OutputMode | string;
    currentTrack: Track;
    queueCount: number;
};

export type RecommendationSection = {
    id: string;
    title: string;
    tracks: Track[];
};

export type SmartPlaylist = {
    id: string;
    title: string;
    description: string;
    tracks: Track[];
};

export type PlayerProfile = {
    userId: number;
    name: string;
    bio: string;
    avatar: string;
    isPublic: boolean;
    showActivity: boolean;
    following: boolean;
    followerCount: number;
    followingCount: number;
    publicPlaylists: PlaylistSummary[];
    followingProfiles: SocialProfile[];
};

export type SocialProfile = {
    userId: number;
    name: string;
    bio: string;
    avatar: string;
    isPublic: boolean;
    showActivity: boolean;
    following: boolean;
    followerCount: number;
    followingCount: number;
    publicPlaylists: PlaylistSummary[];
};

export type SocialSearchResults = {
    profiles: SocialProfile[];
    playlists: PlaylistSummary[];
};

export type LibraryState = {
    favorites: Track[];
    playlists: PlaylistSummary[];
    history: Track[];
    stations: Station[];
    sharedSessions: SharedSession[];
    friendsListening: SharedSession[];
    followingProfiles: SocialProfile[];
    recommendations: RecommendationSection[];
    smartPlaylists: SmartPlaylist[];
};

export type AudioState = {
    output: OutputMode;
    volume: number;
    muted: boolean;
};

export type InitialState = {
    locale?: string;
    appName?: string;
    profile: PlayerProfile;
    playback: PlaybackState;
    library: LibraryState;
    audio: AudioState;
};

export type PlaybackAction = "pause" | "resume" | "play" | "next" | "prev" | "stop";

export type LibraryTab = "playlists" | "favorites" | "history" | "social";

export type AppView = "home" | "search" | "library" | "player" | "playlist" | "profile";
