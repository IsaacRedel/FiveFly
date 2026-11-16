import { Artwork } from "../components/common";
import { Icon, type IconName } from "../components/Icon";
import { greetingKey, translateSection, useT } from "../i18n";
import { useHorizontalDragScroll } from "../lib/useHorizontalDragScroll";
import { useFiveFly } from "../state/store";
import type { Track } from "../types";

type Tile = {
    id: string;
    title: string;
    subtitle: string;
    image: string;
    action: () => void;
    icon?: IconName;
    iconAction?: () => void;
};

function QuickGrid() {
    const t = useT();
    const { data, currentTrack, isPlaying, actions } = useFiveFly();
    const { library } = data;
    const recommendation = library.recommendations.find((section) => section.id === "time" && section.tracks.length > 0)
        || library.recommendations.find((section) => section.tracks.length > 0);
    const recommendedTrack = recommendation?.tracks[0];
    const playlist = library.playlists[0];
    const session = library.friendsListening[0];
    const station = library.stations[0];
    const favorite = library.favorites[0];

    const tiles: Tile[] = [];

    if (currentTrack) {
        tiles.push({
            id: "now",
            title: t("home.nowPlaying"),
            subtitle: currentTrack.title,
            image: currentTrack.thumbnail,
            action: () => actions.openView("player"),
            icon: isPlaying ? "pause" : "play",
            iconAction: actions.togglePlay
        });
    }

    if (recommendedTrack && recommendation) {
        tiles.push({ id: "time", title: t("home.rightNow"), subtitle: recommendedTrack.title, image: recommendedTrack.thumbnail, action: () => actions.play(recommendedTrack, recommendation.tracks) });
    }

    if (playlist) {
        tiles.push({ id: "playlist", title: t("home.yourPlaylists"), subtitle: playlist.name, image: playlist.cover || "", action: () => actions.openPlaylist(playlist.id) });
    }

    if (session) {
        tiles.push({ id: "live", title: t("home.live"), subtitle: session.host, image: session.currentTrack.thumbnail, action: () => actions.joinSession(session.source) });
    }

    if (station?.tracks[0]) {
        tiles.push({ id: "radio", title: t("home.radios"), subtitle: station.name, image: station.cover, action: () => actions.play(station.tracks[0], station.tracks) });
    }

    if (favorite) {
        tiles.push({ id: "liked", title: t("home.liked"), subtitle: favorite.title, image: favorite.thumbnail, action: () => actions.play(favorite, library.favorites) });
    }

    if (tiles.length === 0) return null;

    return (
        <section className="home-quick-grid" aria-label={t("home.shortcuts")}>
            {tiles.slice(0, 6).map((tile) => (
                <div className="quick-tile" key={tile.id}>
                    <button className="quick-tile-main" type="button" onClick={tile.action}>
                        <Artwork image={tile.image} size="mini" />
                        <span>
                            <strong>{tile.title}</strong>
                            <em>{tile.subtitle}</em>
                        </span>
                    </button>
                    {tile.icon && tile.iconAction && (
                        <button className="quick-tile-action" type="button" onClick={tile.iconAction} aria-label={tile.title}>
                            <Icon name={tile.icon} />
                        </button>
                    )}
                </div>
            ))}
        </section>
    );
}

function Stations() {
    const t = useT();
    const { data, actions } = useFiveFly();
    const drag = useHorizontalDragScroll<HTMLDivElement>();
    const { stations } = data.library;

    if (stations.length === 0) return null;

    return (
        <section className="section-block">
            <h2>{t("home.stations")}</h2>
            <div className="radio-station-grid drag-scroll" {...drag}>
                {stations.map((station) => (
                    <button className="radio-station-tile" type="button" key={station.id} onClick={() => station.tracks[0] && actions.play(station.tracks[0], station.tracks)}>
                        <span className="radio-station-cover">
                            <Artwork image={station.cover || station.tracks[0]?.thumbnail} size="tile" />
                            <span className="recent-play-overlay"><Icon name="play" /></span>
                        </span>
                        <span>
                            <strong>{station.name}</strong>
                            <em>{station.description}</em>
                        </span>
                    </button>
                ))}
            </div>
        </section>
    );
}

function MadeForYou() {
    const t = useT();
    const { data, actions } = useFiveFly();
    const drag = useHorizontalDragScroll<HTMLDivElement>();
    const { recommendations, smartPlaylists } = data.library;

    const items: Array<{ id: string; title: string; tracks: Track[] }> = [
        ...recommendations.filter((section) => section.tracks.length > 0),
        ...smartPlaylists.filter((playlist) => playlist.id !== "most-skipped" && playlist.tracks.length > 0)
    ].slice(0, 4).map((section) => ({ id: section.id, title: translateSection(t, section.id, section.title), tracks: section.tracks }));

    return (
        <section className="section-block">
            <h2>{t("home.madeForYou")}</h2>
            {items.length > 0 ? (
                <div className="for-you-grid drag-scroll" {...drag}>
                    {items.map((section) => (
                        <button className="for-you-card for-you-tile" type="button" key={section.id} onClick={() => actions.play(section.tracks[0], section.tracks)}>
                            <span className="for-you-cover">
                                <Artwork track={section.tracks[0]} size="tile" />
                                <span className="recent-play-overlay"><Icon name="play" /></span>
                            </span>
                            <span>
                                <strong>{section.title}</strong>
                                <em>{section.tracks[0].title}</em>
                            </span>
                        </button>
                    ))}
                </div>
            ) : (
                <div className="discovery-empty">
                    <strong>{t("home.noSuggestions")}</strong>
                    <span>{t("home.noSuggestionsHint")}</span>
                </div>
            )}
        </section>
    );
}

function KeepListening() {
    const t = useT();
    const { data, actions } = useFiveFly();
    const { history, playlists } = data.library;

    const items = [
        ...playlists.slice(0, 2).map((playlist) => ({
            id: `playlist-${playlist.id}`,
            title: playlist.name,
            subtitle: t("common.tracks", { count: playlist.trackCount }),
            image: playlist.cover || "",
            onClick: () => actions.openPlaylist(playlist.id)
        })),
        ...history.slice(0, 2).map((track) => ({
            id: `track-${track.videoId}`,
            title: track.title,
            subtitle: track.author || t("common.unknownArtist"),
            image: track.thumbnail,
            onClick: () => actions.play(track, history)
        }))
    ].slice(0, 4);

    return (
        <section className="section-block">
            <h2>{t("home.continue")}</h2>
            {items.length > 0 ? (
                <div className="continue-grid">
                    {items.map((item) => (
                        <button className="continue-card" type="button" key={item.id} onClick={item.onClick}>
                            <Artwork image={item.image} size="small" />
                            <span>
                                <strong>{item.title}</strong>
                                <em>{item.subtitle}</em>
                            </span>
                        </button>
                    ))}
                </div>
            ) : (
                <div className="discovery-empty">
                    <strong>{t("home.nothingYet")}</strong>
                    <span>{t("home.nothingYetHint")}</span>
                </div>
            )}
        </section>
    );
}

export function LiveSessions({ limit = 2 }: { limit?: number }) {
    const t = useT();
    const { data, actions } = useFiveFly();
    // Only profiles the player follows (and that allow showing activity), as filtered by the server.
    const sessions = data.library.friendsListening;

    if (sessions.length === 0) return null;

    return (
        <section className="section-block">
            <div className="section-title-row">
                <h2>{t("home.liveNearby")}</h2>
                <button type="button" onClick={actions.refreshSessions}>{t("common.refresh")}</button>
            </div>
            <div className="shared-session-list">
                {sessions.slice(0, limit).map((session) => (
                    <button className="shared-session-card" type="button" key={session.source} onClick={() => actions.joinSession(session.source)}>
                        <Artwork track={session.currentTrack} size="small" />
                        <span>
                            <strong>{session.host}</strong>
                            <em>{session.currentTrack.title} · {t("home.inQueue", { count: session.queueCount })}</em>
                        </span>
                        <small>{t("home.joinSession")}</small>
                    </button>
                ))}
            </div>
        </section>
    );
}

export function HomeView({ showHeader = true }: { showHeader?: boolean }) {
    const t = useT();
    const { data, actions } = useFiveFly();

    return (
        <div className="view-stack home-view">
            {showHeader && (
                <header className="home-head">
                    <div>
                        <h1>{t(greetingKey())}</h1>
                        <button className="home-profile-line" type="button" onClick={() => actions.openProfile(data.profile.userId)}>
                            <span>{data.profile.name}</span>
                        </button>
                    </div>
                    <div className="home-head-actions">
                        <button className="icon-button muted" type="button" onClick={() => actions.setSheet({ type: "settings" })} aria-label={t("common.settings")}>
                            <Icon name="settings" />
                        </button>
                        <button className="home-profile-avatar" type="button" onClick={() => actions.openProfile(data.profile.userId)} aria-label={t("common.openProfile")}>
                            <Artwork image={data.profile.avatar} size="mini" />
                        </button>
                    </div>
                </header>
            )}

            {!showHeader && <h1 className="panel-greeting">{t(greetingKey())}</h1>}

            <QuickGrid />
            <Stations />
            <MadeForYou />
            <KeepListening />
            <LiveSessions />
        </div>
    );
}
