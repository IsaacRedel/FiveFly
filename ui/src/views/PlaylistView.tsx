import { EmptyState, PlaylistCover, TrackList } from "../components/common";
import { Icon } from "../components/Icon";
import { useT } from "../i18n";
import { durationToSeconds, formatTime } from "../lib/time";
import { useFiveFly } from "../state/store";

export function PlaylistView() {
    const t = useT();
    const { selectedPlaylist: playlist, selectedPlaylistTracks: tracks, data, actions } = useFiveFly();

    if (!playlist) {
        return <EmptyState icon="library" title={t("playlist.notFound")} description={t("playlist.notFoundHint")} actionLabel={t("common.back")} onAction={() => actions.openView("library")} />;
    }

    const totalSeconds = tracks.reduce((total, track) => total + durationToSeconds(track.duration), 0);
    const playAll = () => tracks[0] && actions.play(tracks[0], tracks);

    return (
        <div className="playlist-view">
            <header className="playlist-hero">
                <button className="icon-button floating" type="button" onClick={() => actions.openView("library")} aria-label={t("common.back")}>
                    <Icon name="back" />
                </button>
                <button className="icon-button floating floating-right" type="button" onClick={actions.deleteSelectedPlaylist} aria-label={t("playlist.delete")}>
                    <Icon name="trash" />
                </button>
                <button className="playlist-cover-button" type="button" onClick={() => actions.setSheet({ type: "playlistCover" })} aria-label={t("playlist.editCover")}>
                    <PlaylistCover playlist={playlist} tracks={tracks} />
                </button>
                <div className="playlist-title-row">
                    <div>
                        <h1>{playlist.name}</h1>
                        <p>{t("common.tracks", { count: playlist.trackCount })}</p>
                    </div>
                    <button className="round-action" type="button" onClick={playAll} aria-label={t("playlist.playAll")}>
                        <Icon name="play" />
                    </button>
                </div>
                <div className="playlist-meta-row">
                    <span>{t("playlist.inQueue", { count: tracks.length })}</span>
                    <span>{formatTime(totalSeconds)}</span>
                    <button className="playlist-visibility-chip" type="button" onClick={() => actions.setPlaylistVisibility(playlist, playlist.visibility === "public" ? "private" : "public")}>
                        {playlist.visibility === "public" ? t("playlist.public") : t("playlist.private")}
                    </button>
                </div>
                {playlist.shareCode && (
                    <div className="playlist-share-code">
                        <span>
                            <em>{t("playlist.code")}</em>
                            <strong>{playlist.shareCode}</strong>
                        </span>
                        <button className="playlist-share-copy" type="button" onClick={() => playlist.shareCode && actions.copyPlaylistCode(playlist.shareCode)}>
                            {t("playlist.copyCode")}
                        </button>
                    </div>
                )}
                <div className="playlist-detail-actions">
                    <button type="button" disabled={tracks.length === 0} onClick={playAll}>
                        <Icon name="play" />
                        <span>{t("playlist.playAll")}</span>
                    </button>
                    <button type="button" onClick={() => actions.openView("search")}>
                        <Icon name="search" />
                        <span>{t("playlist.addTracks")}</span>
                    </button>
                    <button type="button" onClick={actions.deleteSelectedPlaylist} aria-label={t("playlist.delete")}>
                        <Icon name="trash" />
                        <span>{t("playlist.deleteShort")}</span>
                    </button>
                </div>
            </header>
            {tracks.length > 0 ? (
                <TrackList tracks={tracks} favorites={data.library.favorites} onPlay={(track) => actions.play(track, tracks)} onFavorite={actions.toggleTrackFavorite} onMore={actions.openTrackActions} numbered />
            ) : (
                <EmptyState icon="music" title={t("playlist.empty")} description={t("playlist.emptyHint")} actionLabel={t("playlist.addTracks")} onAction={() => actions.openView("search")} />
            )}
        </div>
    );
}
