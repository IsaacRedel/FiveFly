import { useEffect, useRef, useState, type CSSProperties } from "react";
import { Artwork, EmptyState } from "../components/common";
import { Icon, type IconName } from "../components/Icon";
import { useT } from "../i18n";
import type { MessageKey } from "../i18n/en";
import { durationToSeconds, formatTime } from "../lib/time";
import { isFavorite } from "../lib/tracks";
import { useFiveFly } from "../state/store";
import type { OutputMode } from "../types";

export const OUTPUT_ICONS: Record<OutputMode, IconName> = { prop: "speaker", vehicle: "car", private: "headphones", off: "off" };
export const OUTPUT_LABELS: Record<OutputMode, MessageKey> = { prop: "output.prop", vehicle: "output.vehicle", private: "output.private", off: "output.off" };

/** Seek bar that only commits the new position when the user releases it. */
export function SeekBar({ compact }: { compact?: boolean }) {
    const t = useT();
    const { currentTrack, liveProgress, actions } = useFiveFly();
    const [draft, setDraft] = useState<number | null>(null);
    const draftRef = useRef<number | null>(null);

    useEffect(() => {
        draftRef.current = null;
        setDraft(null);
    }, [currentTrack?.videoId]);

    if (!currentTrack) return null;

    const duration = liveProgress.duration || durationToSeconds(currentTrack.duration);
    const position = Math.min(liveProgress.position || 0, duration || 0);
    const visible = draft ?? position;
    const percent = duration > 0 ? Math.min(100, (visible / duration) * 100) : 0;
    const durationLabel = currentTrack.duration && currentTrack.duration !== "--:--" ? currentTrack.duration : formatTime(duration);

    function update(value: number) {
        const next = Math.max(0, Math.min(duration, value));
        draftRef.current = next;
        setDraft(next);
    }

    function commit() {
        if (draftRef.current === null) return;

        const next = Math.max(0, Math.min(duration, draftRef.current));
        draftRef.current = null;
        setDraft(null);
        actions.seekTo(next);
    }

    return (
        <section className={compact ? "progress-block compact" : "progress-block"}>
            {compact && <span className="progress-time">{formatTime(visible)}</span>}
            <input
                className="progress-seek"
                type="range"
                min="0"
                max={Math.max(1, Math.floor(duration))}
                step="1"
                value={Math.floor(visible)}
                disabled={duration <= 0}
                onChange={(event) => update(Number(event.target.value))}
                onPointerUp={commit}
                onPointerCancel={commit}
                onKeyUp={commit}
                onBlur={commit}
                aria-label={t("player.progress")}
                aria-valuetext={t("player.progressValue", { position: formatTime(visible), duration: durationLabel })}
                style={{ "--progress": `${percent}%` } as CSSProperties}
            />
            {compact ? (
                <span className="progress-time">{durationLabel}</span>
            ) : (
                <div className="progress-labels">
                    <span>{formatTime(visible)}</span>
                    <span>{durationLabel}</span>
                </div>
            )}
        </section>
    );
}

export function TransportControls() {
    const t = useT();
    const { data, isPlaying, playbackBusy, actions } = useFiveFly();
    const { playback } = data;

    return (
        <section className="player-controls">
            <button className={playback.shuffle ? "mode-button active" : "mode-button"} type="button" onClick={actions.toggleShuffle} aria-label={t("player.shuffle")} aria-pressed={playback.shuffle}>
                <Icon name="shuffle" />
            </button>
            <button className="transport-button" type="button" onClick={() => actions.runTransport("prev")} disabled={playbackBusy} aria-label={t("player.previous")}>
                <Icon name="prev" />
            </button>
            <button className={playbackBusy ? "main-play-button is-busy" : "main-play-button"} type="button" onClick={actions.togglePlay} disabled={playbackBusy} aria-label={isPlaying ? t("player.pause") : t("player.play")}>
                <Icon name={isPlaying ? "pause" : "play"} />
            </button>
            <button className="transport-button" type="button" onClick={() => actions.runTransport("next")} disabled={playbackBusy} aria-label={t("player.next")}>
                <Icon name="next" />
            </button>
            <button className={playback.repeat !== "off" ? "mode-button active" : "mode-button"} type="button" onClick={actions.cycleRepeat} aria-label={t("player.repeat")}>
                <Icon name="repeat" />
                {playback.repeat === "one" && <span>1</span>}
            </button>
        </section>
    );
}

export function VolumeControl() {
    const t = useT();
    const { data, actions } = useFiveFly();
    const { audio } = data;

    return (
        <div className="volume-inline">
            <button className={audio.muted ? "volume-mute-button active" : "volume-mute-button"} type="button" onClick={actions.toggleMute} aria-label={t("player.mute")}>
                <Icon name={audio.muted ? "off" : "speaker"} />
            </button>
            <input type="range" min="0" max="100" value={audio.volume} onChange={(event) => actions.changeVolume(Number(event.target.value))} aria-label={t("player.volume")} />
        </div>
    );
}

export function PlayerView({ onBack }: { onBack?: () => void }) {
    const t = useT();
    const { currentTrack, isPlaying, playbackBusy, data, actions } = useFiveFly();
    const [showVolume, setShowVolume] = useState(false);
    const { audio, playback, library } = data;

    if (!currentTrack) {
        return <EmptyState icon="music" title={t("player.nothing")} description={t("player.nothingHint")} actionLabel={t("library.searchTracks")} onAction={() => actions.openView("search")} />;
    }

    const favorite = isFavorite(currentTrack, library.favorites);
    const upNext = Math.max(0, playback.queue.length - Math.max(1, playback.currentIndex || 1));

    return (
        <div className={`player-view ${isPlaying ? "playing" : ""} ${playbackBusy ? "is-busy" : ""}`}>
            <header className="player-head">
                <button className="icon-button" type="button" onClick={onBack || (() => actions.goBack())} aria-label={t("common.back")}>
                    <Icon name="down" />
                </button>
                <span>{t("player.playingFrom")}</span>
                <button className="icon-button" type="button" aria-label={t("common.more")} onClick={() => actions.openTrackActions(currentTrack)}>
                    <Icon name="more" />
                </button>
            </header>

            <div className="player-cover-wrap">
                <Artwork track={currentTrack} size="cover" />
            </div>

            <section className="player-copy">
                <div>
                    <h1>{currentTrack.title}</h1>
                    <p>{currentTrack.author || t("common.unknownArtist")}</p>
                    <span className={`player-status-chip ${playbackBusy ? "loading" : ""}`}>
                        {playbackBusy ? t("player.loading") : isPlaying ? t("player.playing") : t("player.paused")}
                    </span>
                </div>
                <button className={`heart-button ${favorite ? "active" : ""}`} type="button" onClick={() => actions.toggleTrackFavorite(currentTrack)} aria-label={t("player.like")} aria-pressed={favorite}>
                    <Icon name="heart" />
                </button>
            </section>

            <SeekBar />
            <TransportControls />

            <section className="player-tools">
                <button className={`output-chip ${audio.output !== "off" ? "active" : ""}`} type="button" onClick={() => actions.setSheet({ type: "audio" })}>
                    <Icon name={OUTPUT_ICONS[audio.output]} />
                    <span>{t(OUTPUT_LABELS[audio.output])}</span>
                </button>
                <div className="player-tool-actions">
                    <button className="queue-button" type="button" onClick={() => actions.setSheet({ type: "queue" })} aria-label={t("player.queue")}>
                        <Icon name="queue" />
                        {upNext > 0 && <span>{upNext}</span>}
                    </button>
                    <div className="player-volume-control">
                        <button className={`icon-button sound-toggle ${showVolume ? "active" : ""}`} type="button" onClick={() => setShowVolume((current) => !current)} aria-label={t("player.volume")}>
                            <Icon name={audio.muted ? "off" : "speaker"} />
                        </button>
                        {showVolume && (
                            <div className="player-volume-popover">
                                <VolumeControl />
                                <strong>{audio.volume}%</strong>
                            </div>
                        )}
                    </div>
                </div>
            </section>
        </div>
    );
}
