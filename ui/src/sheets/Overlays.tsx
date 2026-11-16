import { useState } from "react";
import { hasLbPhoneGallery } from "../bridge/nui";
import { Artwork, Sheet, TrackCopy } from "../components/common";
import { Icon } from "../components/Icon";
import { useT } from "../i18n";
import { isFavorite } from "../lib/tracks";
import { useFiveFY } from "../state/store";
import type { OutputMode, Track } from "../types";
import { OUTPUT_ICONS, OUTPUT_LABELS } from "../views/PlayerView";

const OUTPUTS: OutputMode[] = ["private", "prop", "vehicle", "off"];
const OUTPUT_DESCRIPTIONS = { prop: "output.propDesc", vehicle: "output.vehicleDesc", private: "output.privateDesc", off: "output.offDesc" } as const;

function VolumeRow() {
    const t = useT();
    const { data, actions } = useFiveFY();
    const { audio } = data;

    return (
        <div className="audio-controls">
            <button className={audio.muted ? "mute-toggle active" : "mute-toggle"} type="button" onClick={actions.toggleMute}>
                <Icon name={audio.muted ? "off" : "speaker"} />
                <span>{audio.muted ? t("output.muted") : t("output.active")}</span>
            </button>
            <label className="sheet-volume">
                <span>{t("player.volume")}</span>
                <strong>{audio.volume}%</strong>
                <input type="range" min="0" max="100" value={audio.volume} onChange={(event) => actions.changeVolume(Number(event.target.value))} />
            </label>
        </div>
    );
}

function AudioSheet({ onClose }: { onClose: () => void }) {
    const t = useT();
    const { data, actions } = useFiveFY();

    return (
        <Sheet className="output-sheet" title={t("output.title")} onClose={onClose}>
            <VolumeRow />
            <div className="output-options">
                {OUTPUTS.map((output) => (
                    <button className={data.audio.output === output ? "active" : ""} type="button" key={output} onClick={() => actions.chooseOutput(output)}>
                        <span className="output-icon"><Icon name={OUTPUT_ICONS[output]} /></span>
                        <span>
                            <strong>{t(OUTPUT_LABELS[output])}</strong>
                            <em>{t(OUTPUT_DESCRIPTIONS[output])}</em>
                        </span>
                    </button>
                ))}
            </div>
        </Sheet>
    );
}

function SettingsSheet({ onClose }: { onClose: () => void }) {
    const t = useT();
    const { data, actions } = useFiveFY();

    return (
        <Sheet className="settings-sheet" kicker="FiveFY" title={t("common.settings")} onClose={onClose}>
            <div className="settings-output-grid">
                {OUTPUTS.map((output) => (
                    <button className={data.audio.output === output ? "active" : ""} type="button" key={output} onClick={() => actions.chooseOutput(output)}>
                        <Icon name={OUTPUT_ICONS[output]} />
                        <span>{t(OUTPUT_LABELS[output])}</span>
                    </button>
                ))}
            </div>
            <VolumeRow />
            <div className="settings-action-list">
                <button type="button" onClick={actions.refreshDiscovery}>
                    <Icon name="search" />
                    <span>
                        <strong>{t("settings.refresh")}</strong>
                        <em>{t("settings.refreshHint")}</em>
                    </span>
                </button>
                <button className="danger" type="button" onClick={actions.clearHistory}>
                    <Icon name="trash" />
                    <span>
                        <strong>{t("settings.clearHistory")}</strong>
                        <em>{t("settings.clearHistoryHint")}</em>
                    </span>
                </button>
            </div>
        </Sheet>
    );
}

function ProfileEditSheet({ onClose }: { onClose: () => void }) {
    const t = useT();
    const { data, actions } = useFiveFY();
    const { profile } = data;
    const [bio, setBio] = useState(profile.bio || "");
    const [avatar, setAvatar] = useState(profile.avatar || "");
    const [showUrl, setShowUrl] = useState(!hasLbPhoneGallery());
    const [isPublic, setIsPublic] = useState(profile.isPublic !== false);
    const [showActivity, setShowActivity] = useState(profile.showActivity !== false);

    function chooseFromGallery() {
        actions.chooseAvatarFromGallery().then((photo) => {
            if (!photo) return;
            setAvatar(photo);
            setShowUrl(false);
        });
    }

    return (
        <Sheet className="profile-edit-sheet" kicker={profile.name} title={t("profile.edit")} onClose={onClose}>
            <div className="profile-settings-block">
                <div className="avatar-source-actions">
                    {hasLbPhoneGallery() && (
                        <button type="button" onClick={chooseFromGallery}>
                            <Icon name="image" />
                            <span>{t("profile.useGallery")}</span>
                        </button>
                    )}
                    <button type="button" onClick={() => setShowUrl((current) => !current)}>
                        <Icon name="paperclip" />
                        <span>{t("profile.uploadLink")}</span>
                    </button>
                </div>
                {showUrl && (
                    <label>
                        <span>{t("profile.avatarUrl")}</span>
                        <input value={avatar} onChange={(event) => setAvatar(event.target.value)} maxLength={512} placeholder="https://..." />
                    </label>
                )}
                <label>
                    <span>{t("profile.bio")}</span>
                    <input value={bio} onChange={(event) => setBio(event.target.value)} maxLength={140} placeholder={t("profile.bioPlaceholder")} />
                </label>
                <div className="settings-toggle-row">
                    <label>
                        <input type="checkbox" checked={isPublic} onChange={(event) => setIsPublic(event.target.checked)} />
                        <span>{t("profile.public")}</span>
                    </label>
                    <label>
                        <input type="checkbox" checked={showActivity} onChange={(event) => setShowActivity(event.target.checked)} />
                        <span>{t("profile.showActivity")}</span>
                    </label>
                </div>
                <button className="primary-sheet-button compact" type="button" onClick={() => actions.updateProfile({ bio, avatar, isPublic, showActivity })}>
                    {t("profile.save")}
                </button>
            </div>
        </Sheet>
    );
}

function QueueSheet({ onClose }: { onClose: () => void }) {
    const t = useT();
    const { data, actions } = useFiveFY();
    const { playback } = data;
    const currentIndex = Math.max(0, (playback.currentIndex || 1) - 1);
    const currentTrack = playback.currentTrack || playback.queue[currentIndex] || null;
    const queue = playback.queue.length > 0 ? playback.queue : currentTrack ? [currentTrack] : [];

    return (
        <Sheet className="queue-sheet" kicker={t("queue.kicker")} title={t("queue.title")} onClose={onClose}>
            {currentTrack ? (
                <>
                    <span className="queue-section-label">{t("queue.nowPlaying")}</span>
                    <article className="queue-now">
                        <Artwork track={currentTrack} size="mini" />
                        <TrackCopy track={currentTrack} strong />
                    </article>
                </>
            ) : (
                <div className="playlist-select-empty">
                    <Icon name="queue" />
                    <strong>{t("queue.empty")}</strong>
                    <p>{t("queue.emptyHint")}</p>
                </div>
            )}

            {queue.length > 0 && (
                <>
                    <span className="queue-section-label">{t("queue.next")}</span>
                    <div className="queue-list">
                        {queue.map((track, index) => {
                            const active = index === currentIndex;

                            return (
                                <div className={active ? "queue-row active" : "queue-row"} key={`${track.videoId}-${index}`}>
                                    <button type="button" disabled={active} onClick={() => actions.play(track, playback.queue)}>
                                        <Artwork track={track} size="mini" />
                                        <TrackCopy track={track} />
                                    </button>
                                    <div className="queue-row-actions">
                                        {active ? (
                                            <span className="queue-status">{t("queue.playing")}</span>
                                        ) : (
                                            <>
                                                <span className="queue-reorder-controls">
                                                    <button className="icon-button muted" type="button" onClick={() => actions.moveQueueItem(index, -1)} disabled={index === 0} aria-label={t("queue.moveUp")}>
                                                        <Icon name="up" />
                                                    </button>
                                                    <button className="icon-button muted" type="button" onClick={() => actions.moveQueueItem(index, 1)} disabled={index === queue.length - 1} aria-label={t("queue.moveDown")}>
                                                        <Icon name="down" />
                                                    </button>
                                                </span>
                                                <button className="icon-button muted" type="button" onClick={() => actions.removeFromQueue(index)} disabled={index < currentIndex} aria-label={t("queue.remove")}>
                                                    <Icon name="trash" />
                                                </button>
                                            </>
                                        )}
                                    </div>
                                </div>
                            );
                        })}
                    </div>
                </>
            )}
        </Sheet>
    );
}

function TrackActionSheet({ track, onClose }: { track: Track; onClose: () => void }) {
    const t = useT();
    const { data, view, selectedPlaylist, actions } = useFiveFY();
    const favorite = isFavorite(track, data.library.favorites);
    const inPlaylist = view === "playlist" && !!selectedPlaylist;

    return (
        <Sheet
            className="track-action-sheet"
            onClose={onClose}
            head={(
                <header className="action-track-head">
                    <Artwork track={track} size="mini" />
                    <TrackCopy track={track} strong />
                    <button className="icon-button" type="button" onClick={onClose} aria-label={t("common.close")}><Icon name="close" /></button>
                </header>
            )}
        >
            <div className="action-list">
                <button type="button" onClick={() => { actions.play(track); onClose(); }}>
                    <Icon name="play" />
                    <span>{t("track.playNow")}</span>
                </button>
                <button type="button" onClick={() => actions.toggleTrackFavorite(track)}>
                    <Icon name="heart" />
                    <span>{favorite ? t("track.unlike") : t("track.like")}</span>
                </button>
                <button type="button" onClick={() => actions.setSheet(data.library.playlists.length > 0 ? { type: "playlistSelect", track } : { type: "playlistCreate" })}>
                    <Icon name="library" />
                    <span>{data.library.playlists.length > 0 ? t("track.addToPlaylist") : t("track.createPlaylist")}</span>
                </button>
                {inPlaylist && track.thumbnail && (
                    <button type="button" onClick={() => actions.setPlaylistCover(track.thumbnail)}>
                        <Icon name="image" />
                        <span>{t("track.useAsCover")}</span>
                    </button>
                )}
                {inPlaylist && (
                    <button type="button" onClick={() => actions.removeTrackFromPlaylist(track)}>
                        <Icon name="trash" />
                        <span>{t("track.removeFromPlaylist")}</span>
                    </button>
                )}
            </div>
        </Sheet>
    );
}

function PlaylistSelectSheet({ track, onClose }: { track: Track; onClose: () => void }) {
    const t = useT();
    const { data, actions } = useFiveFY();

    return (
        <Sheet className="playlist-select-sheet" kicker={t("playlistSelect.kicker")} title={track.title} onClose={onClose}>
            {data.library.playlists.length > 0 ? (
                <div className="playlist-select-list">
                    {data.library.playlists.map((playlist) => (
                        <button className="playlist-select-row" type="button" key={playlist.id} onClick={() => actions.addTrackToPlaylist(track, playlist.id)}>
                            <Artwork image={playlist.cover || ""} size="small" />
                            <span>
                                <strong>{playlist.name}</strong>
                                <em>{t("common.tracks", { count: playlist.trackCount })}</em>
                            </span>
                            <Icon name="next" />
                        </button>
                    ))}
                </div>
            ) : (
                <div className="playlist-select-empty">
                    <Icon name="library" />
                    <strong>{t("playlistSelect.empty")}</strong>
                    <p>{t("playlistSelect.emptyHint")}</p>
                </div>
            )}
            <button className="primary-sheet-button" type="button" onClick={() => actions.setSheet({ type: "playlistCreate" })}>
                {t("playlistSelect.create")}
            </button>
        </Sheet>
    );
}

/** Single text field + submit button (create playlist, import code, cover URL). */
function InputSheet({ className, title, kicker, initial = "", placeholder, maxLength, submitLabel, transform, onSubmit, onClose }: {
    className: string;
    title: string;
    kicker?: string;
    initial?: string;
    placeholder: string;
    maxLength: number;
    submitLabel: string;
    transform?: (value: string) => string;
    onSubmit: (value: string) => void;
    onClose: () => void;
}) {
    const [value, setValue] = useState(initial);
    const safe = value.trim();

    return (
        <Sheet className={`input-sheet ${className}`} kicker={kicker} title={title} onClose={onClose}>
            <form className="input-sheet-form" onSubmit={(event) => { event.preventDefault(); if (safe) onSubmit(safe); }}>
                <input value={value} onChange={(event) => setValue(transform ? transform(event.target.value) : event.target.value)} maxLength={maxLength} placeholder={placeholder} autoFocus />
                <button className="primary-sheet-button" type="submit" disabled={!safe}>
                    {submitLabel}
                </button>
            </form>
        </Sheet>
    );
}

export function Overlays() {
    const t = useT();
    const { sheet, selectedPlaylist, actions } = useFiveFY();
    const close = () => actions.setSheet(null);

    if (!sheet) return null;

    switch (sheet.type) {
        case "audio":
            return <AudioSheet onClose={close} />;
        case "settings":
            return <SettingsSheet onClose={close} />;
        case "profileEdit":
            return <ProfileEditSheet onClose={close} />;
        case "queue":
            return <QueueSheet onClose={close} />;
        case "trackActions":
            return <TrackActionSheet track={sheet.track} onClose={close} />;
        case "playlistSelect":
            return <PlaylistSelectSheet track={sheet.track} onClose={close} />;
        case "playlistCreate":
            return <InputSheet className="playlist-create-sheet" title={t("playlistCreate.title")} placeholder={t("playlistCreate.placeholder")} maxLength={48} submitLabel={t("playlistCreate.submit")} onSubmit={actions.createPlaylist} onClose={close} />;
        case "playlistImport":
            return <InputSheet className="playlist-create-sheet" title={t("playlistImport.title")} placeholder={t("playlistImport.placeholder")} maxLength={12} submitLabel={t("playlistImport.submit")} transform={(value) => value.toUpperCase()} onSubmit={actions.importPlaylist} onClose={close} />;
        case "playlistCover":
            return selectedPlaylist ? (
                <InputSheet className="playlist-cover-url-sheet" kicker={selectedPlaylist.name} title={t("playlistCover.title")} initial={selectedPlaylist.cover || ""} placeholder="https://..." maxLength={512} submitLabel={t("playlistCover.submit")} onSubmit={actions.setPlaylistCover} onClose={close} />
            ) : null;
        default:
            return null;
    }
}
