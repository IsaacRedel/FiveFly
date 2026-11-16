import { useT } from "../i18n";
import { useFiveFY } from "../state/store";
import type { AppView } from "../types";
import { Artwork, TrackCopy } from "./common";
import { Icon, type IconName } from "./Icon";

export function BottomNav() {
    const t = useT();
    const { view, actions } = useFiveFY();
    const items: Array<{ view: AppView; icon: IconName; label: string }> = [
        { view: "home", icon: "home", label: t("nav.home") },
        { view: "search", icon: "search", label: t("nav.search") },
        { view: "library", icon: "library", label: t("nav.library") }
    ];

    return (
        <nav className="bottom-nav">
            {items.map((item) => (
                <button className={view === item.view ? "active" : ""} type="button" key={item.view} onClick={() => actions.openView(item.view)}>
                    <Icon name={item.icon} />
                    <span>{item.label}</span>
                </button>
            ))}
        </nav>
    );
}

export function MiniPlayer() {
    const t = useT();
    const { currentTrack, isPlaying, playbackBusy, actions } = useFiveFY();

    if (!currentTrack) return null;

    return (
        <div className={playbackBusy ? "mini-player is-busy" : "mini-player"}>
            <button className="mini-player-open" type="button" onClick={() => actions.openView("player")}>
                <Artwork track={currentTrack} size="mini" />
                <TrackCopy track={currentTrack} />
            </button>
            <button className="mini-action" type="button" disabled={playbackBusy} onClick={actions.togglePlay} aria-label={isPlaying ? t("player.pause") : t("player.play")}>
                <Icon name={isPlaying ? "pause" : "play"} />
            </button>
            <button className="mini-action muted" type="button" disabled={playbackBusy} onClick={() => actions.runTransport("next")} aria-label={t("player.next")}>
                <Icon name="next" />
            </button>
        </div>
    );
}

export function Toasts() {
    const { error, notice, actions } = useFiveFY();

    if (error) {
        return (
            <button className="toast-error" type="button" onClick={actions.dismissError}>
                {error}
            </button>
        );
    }

    if (notice) {
        return (
            <button className="toast-notice" type="button" onClick={actions.dismissNotice}>
                {notice}
            </button>
        );
    }

    return null;
}
