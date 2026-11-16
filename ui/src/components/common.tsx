import type { ReactNode } from "react";
import { useT } from "../i18n";
import { isFavorite, smartCoverImages } from "../lib/tracks";
import type { PlaylistSummary, Track } from "../types";
import { Icon, type IconName } from "./Icon";

export type ArtworkSize = "mini" | "small" | "medium" | "large" | "tile" | "list" | "cover" | "playlist";

export function Artwork({ track, image, size }: { track?: Track | null; image?: string; size: ArtworkSize }) {
    const source = image || track?.thumbnail || "";

    return (
        <span
            className={`artwork artwork--${size}${source ? "" : " artwork--empty"}`}
            style={source ? { backgroundImage: `url("${source.replace(/"/g, "%22")}")` } : undefined}
        />
    );
}

export function TrackCopy({ track, strong }: { track: Track; strong?: boolean }) {
    const t = useT();

    return (
        <span className={`track-copy ${strong ? "strong" : ""}`}>
            <strong>{track.title}</strong>
            <em>{track.author || t("common.unknownArtist")}</em>
        </span>
    );
}

export function TrackList({ tracks, favorites, onPlay, onFavorite, onMore, numbered }: {
    tracks: Track[];
    favorites: Track[];
    onPlay: (track: Track) => void;
    onFavorite: (track: Track) => void;
    onMore: (track: Track) => void;
    numbered?: boolean;
}) {
    const t = useT();

    return (
        <div className="track-list">
            {tracks.map((track, index) => (
                <div className={numbered ? "track-row numbered" : "track-row"} key={`${track.videoId}-${index}`}>
                    <button className="track-row-main" type="button" onClick={() => onPlay(track)}>
                        {numbered && <span className="track-number">{index + 1}</span>}
                        <Artwork track={track} size="list" />
                        <TrackCopy track={track} />
                        <span className="track-duration">{track.duration}</span>
                    </button>
                    <button className={`heart-button small ${isFavorite(track, favorites) ? "active" : ""}`} type="button" onClick={() => onFavorite(track)} aria-label={t("player.like")}>
                        <Icon name="heart" />
                    </button>
                    <button className="more-button" type="button" onClick={() => onMore(track)} aria-label={t("common.more")}>
                        <Icon name="more" />
                    </button>
                </div>
            ))}
        </div>
    );
}

export function EmptyState({ icon, title, description, actionLabel, onAction }: {
    icon: IconName;
    title: string;
    description: string;
    actionLabel?: string;
    onAction?: () => void;
}) {
    return (
        <div className="empty-state">
            <span className="empty-state-icon">
                <Icon name={icon} />
            </span>
            <strong>{title}</strong>
            <p>{description}</p>
            {actionLabel && onAction && (
                <button className="empty-state-action" type="button" onClick={onAction}>
                    {actionLabel}
                </button>
            )}
        </div>
    );
}

export function TabButton({ children, active, onClick }: { children: ReactNode; active: boolean; onClick: () => void }) {
    return (
        <button className={active ? "active" : ""} type="button" onClick={onClick}>
            {children}
        </button>
    );
}

export function PlaylistCover({ playlist, tracks }: { playlist: PlaylistSummary; tracks: Track[] }) {
    if (playlist.cover) {
        return <Artwork image={playlist.cover} size="playlist" />;
    }

    const images = smartCoverImages(tracks);

    if (images.length <= 1) {
        return <Artwork image={images[0]} size="playlist" />;
    }

    return (
        <span className="artwork artwork--playlist smart-cover-grid">
            {images.map((image, index) => (
                <span className="smart-cover-cell" key={`${image}-${index}`} style={{ backgroundImage: `url("${image}")` }} />
            ))}
        </span>
    );
}

/** Modal sheet: slides up on the phone, centered dialog on the panel. */
export function Sheet({ className, kicker, title, onClose, children, head }: {
    className: string;
    kicker?: string;
    title?: string;
    onClose: () => void;
    children: ReactNode;
    head?: ReactNode;
}) {
    const t = useT();

    return (
        <div className="sheet-backdrop" onClick={onClose}>
            <section className={`sheet ${className}`} role="dialog" aria-modal="true" onClick={(event) => event.stopPropagation()}>
                <span className="sheet-handle" aria-hidden="true" />
                {head || (
                    <header className="sheet-head">
                        <div>
                            {kicker && <span>{kicker}</span>}
                            {title && <h2>{title}</h2>}
                        </div>
                        <button className="icon-button" type="button" onClick={onClose} aria-label={t("common.close")}>
                            <Icon name="close" />
                        </button>
                    </header>
                )}
                {children}
            </section>
        </div>
    );
}
