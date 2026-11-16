import { useEffect } from "react";
import { Toasts } from "../components/chrome";
import { Artwork, TrackCopy } from "../components/common";
import { Icon, type IconName } from "../components/Icon";
import { useT } from "../i18n";
import { isFavorite } from "../lib/tracks";
import { Overlays } from "../sheets/Overlays";
import { useFiveFly } from "../state/store";
import type { AppView } from "../types";
import { OUTPUT_ICONS, OUTPUT_LABELS, SeekBar, TransportControls, VolumeControl } from "../views/PlayerView";
import { CurrentView } from "./views";

function Sidebar() {
    const t = useT();
    const { view, data, selectedPlaylist, actions } = useFiveFly();
    const items: Array<{ view: AppView; icon: IconName; label: string }> = [
        { view: "home", icon: "home", label: t("nav.home") },
        { view: "search", icon: "search", label: t("nav.search") },
        { view: "library", icon: "library", label: t("nav.library") }
    ];

    return (
        <aside className="panel-sidebar">
            <div className="panel-brand">
                <span className="panel-brand-mark" aria-hidden="true" />
                <strong>FiveFly</strong>
            </div>

            <nav className="panel-nav">
                {items.map((item) => (
                    <button className={view === item.view ? "active" : ""} type="button" key={item.view} onClick={() => actions.openView(item.view)}>
                        <Icon name={item.icon} />
                        <span>{item.label}</span>
                    </button>
                ))}
            </nav>

            <div className="panel-sidebar-section">
                <div className="panel-sidebar-title">
                    <span>{t("panel.yourPlaylists")}</span>
                    <button className="icon-button muted" type="button" onClick={() => actions.setSheet({ type: "playlistCreate" })} aria-label={t("panel.newPlaylist")}>
                        <Icon name="plus" />
                    </button>
                </div>
                <div className="panel-sidebar-list">
                    {data.library.playlists.map((playlist) => (
                        <button
                            className={view === "playlist" && selectedPlaylist?.id === playlist.id ? "active" : ""}
                            type="button"
                            key={playlist.id}
                            onClick={() => actions.openPlaylist(playlist.id)}
                        >
                            <Artwork image={playlist.cover || ""} size="mini" />
                            <span>
                                <strong>{playlist.name}</strong>
                                <em>{t("common.tracks", { count: playlist.trackCount })}</em>
                            </span>
                        </button>
                    ))}
                </div>

                {data.library.followingProfiles.length > 0 && (
                    <>
                        <div className="panel-sidebar-title">
                            <span>{t("panel.following")}</span>
                        </div>
                        <div className="panel-sidebar-list">
                            {data.library.followingProfiles.slice(0, 8).map((profile) => (
                                <button type="button" key={profile.userId} onClick={() => actions.openProfile(profile.userId)}>
                                    <Artwork image={profile.avatar} size="mini" />
                                    <span>
                                        <strong>{profile.name}</strong>
                                    </span>
                                </button>
                            ))}
                        </div>
                    </>
                )}
            </div>
        </aside>
    );
}

function NowPlayingBar() {
    const t = useT();
    const { currentTrack, data, view, actions } = useFiveFly();
    const { audio, playback, library } = data;
    const upNext = Math.max(0, playback.queue.length - Math.max(1, playback.currentIndex || 1));

    return (
        <footer className={currentTrack ? "panel-nowbar" : "panel-nowbar is-empty"}>
            <div className="panel-nowbar-track">
                {currentTrack ? (
                    <>
                        <button className="panel-nowbar-cover" type="button" onClick={() => actions.openView(view === "player" ? "home" : "player")} aria-label={t("home.nowPlaying")}>
                            <Artwork track={currentTrack} size="mini" />
                        </button>
                        <TrackCopy track={currentTrack} />
                        <button
                            className={`heart-button small ${isFavorite(currentTrack, library.favorites) ? "active" : ""}`}
                            type="button"
                            onClick={() => actions.toggleTrackFavorite(currentTrack)}
                            aria-label={t("player.like")}
                        >
                            <Icon name="heart" />
                        </button>
                    </>
                ) : (
                    <span className="panel-nowbar-idle">{t("player.nothing")}</span>
                )}
            </div>

            <div className="panel-nowbar-center">
                <TransportControls />
                <SeekBar compact />
            </div>

            <div className="panel-nowbar-tools">
                <button className={view === "player" ? "icon-button active" : "icon-button"} type="button" onClick={() => actions.openView(view === "player" ? "home" : "player")} aria-label={t("home.nowPlaying")}>
                    <Icon name="expand" />
                </button>
                <button className="queue-button" type="button" onClick={() => actions.setSheet({ type: "queue" })} aria-label={t("player.queue")}>
                    <Icon name="queue" />
                    {upNext > 0 && <span>{upNext}</span>}
                </button>
                <button className={`output-chip ${audio.output !== "off" ? "active" : ""}`} type="button" onClick={() => actions.setSheet({ type: "audio" })}>
                    <Icon name={OUTPUT_ICONS[audio.output]} />
                    <span>{t(OUTPUT_LABELS[audio.output])}</span>
                </button>
                <VolumeControl />
            </div>
        </footer>
    );
}

/** Wide layout rendered in the engine page and opened by command/key binding. */
export function PanelShell({ onClose }: { onClose: () => void }) {
    const t = useT();
    const { view, sheet, data, actions } = useFiveFly();

    useEffect(() => {
        const onKeyDown = (event: KeyboardEvent) => {
            if (event.key !== "Escape") return;

            event.preventDefault();

            if (sheet) {
                actions.setSheet(null);
            } else {
                onClose();
            }
        };

        window.addEventListener("keydown", onKeyDown);
        return () => window.removeEventListener("keydown", onKeyDown);
    }, [sheet, actions, onClose]);

    return (
        <main className="fivefly-app is-panel">
            <Sidebar />

            <section className="panel-main">
                <header className="panel-topbar">
                    <span />
                    <div className="panel-topbar-actions">
                        <button className="icon-button muted" type="button" onClick={() => actions.setSheet({ type: "settings" })} aria-label={t("common.settings")}>
                            <Icon name="settings" />
                        </button>
                        <button className="home-profile-avatar" type="button" onClick={() => actions.openProfile(data.profile.userId)} aria-label={t("common.openProfile")}>
                            <Artwork image={data.profile.avatar} size="mini" />
                        </button>
                        <button className="icon-button muted" type="button" onClick={onClose} aria-label={t("panel.close")}>
                            <Icon name="close" />
                        </button>
                    </div>
                </header>
                <div key={view} className={`fivefly-screen fivefly-screen--${view}`}>
                    <CurrentView panel />
                </div>
            </section>

            <NowPlayingBar />
            <Toasts />
            <Overlays />
        </main>
    );
}
