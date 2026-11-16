import { Artwork, EmptyState, TabButton, TrackList } from "../components/common";
import { useT } from "../i18n";
import { useFiveFly } from "../state/store";

export function LibraryView() {
    const t = useT();
    const { libraryTab: tab, data, actions } = useFiveFly();
    const { library } = data;
    const tracks = tab === "favorites" ? library.favorites : library.history;

    return (
        <div className="view-stack library-view">
            <header className="sticky-head">
                <h1>{t("library.title")}</h1>
                <div className="tab-row">
                    <TabButton active={tab === "playlists"} onClick={() => actions.setLibraryTab("playlists")}>{t("library.playlists")}</TabButton>
                    <TabButton active={tab === "favorites"} onClick={() => actions.setLibraryTab("favorites")}>{t("library.favorites")}</TabButton>
                    <TabButton active={tab === "history"} onClick={() => actions.setLibraryTab("history")}>{t("library.history")}</TabButton>
                    <TabButton active={tab === "social"} onClick={() => actions.setLibraryTab("social")}>{t("library.social")}</TabButton>
                </div>
                {tab === "playlists" && (
                    <div className="library-action-row">
                        <button className="create-playlist-button" type="button" onClick={() => actions.setSheet({ type: "playlistCreate" })}>
                            {t("library.create")}
                        </button>
                        <button className="create-playlist-button secondary" type="button" onClick={() => actions.setSheet({ type: "playlistImport" })}>
                            {t("library.import")}
                        </button>
                    </div>
                )}
            </header>

            {tab === "social" ? (
                library.followingProfiles.length === 0 ? (
                    <EmptyState icon="search" title={t("library.noFollowing")} description={t("library.noFollowingHint")} actionLabel={t("library.searchProfiles")} onAction={() => actions.openView("search")} />
                ) : (
                    <div className="library-list">
                        {library.followingProfiles.map((profile) => (
                            <button className="library-playlist" type="button" key={profile.userId} onClick={() => actions.openProfile(profile.userId)}>
                                <Artwork image={profile.avatar || profile.publicPlaylists[0]?.cover || ""} size="medium" />
                                <span>
                                    <strong>{profile.name}</strong>
                                    <em>{t("library.publicCount", { count: profile.publicPlaylists.length })}</em>
                                </span>
                            </button>
                        ))}
                    </div>
                )
            ) : tab === "playlists" ? (
                library.playlists.length === 0 ? (
                    <EmptyState icon="library" title={t("library.noPlaylists")} description={t("library.noPlaylistsHint")} actionLabel={t("library.create")} onAction={() => actions.setSheet({ type: "playlistCreate" })} />
                ) : (
                    <div className="library-list">
                        {library.playlists.map((playlist) => (
                            <button className="library-playlist" type="button" key={playlist.id} onClick={() => actions.openPlaylist(playlist.id)}>
                                <Artwork image={playlist.cover || ""} size="medium" />
                                <span>
                                    <strong>{playlist.name}</strong>
                                    <em>{t("common.tracks", { count: playlist.trackCount })}</em>
                                </span>
                            </button>
                        ))}
                    </div>
                )
            ) : tracks.length > 0 ? (
                <TrackList tracks={tracks} favorites={library.favorites} onPlay={(track) => actions.play(track, tracks)} onFavorite={actions.toggleTrackFavorite} onMore={actions.openTrackActions} />
            ) : (
                <EmptyState
                    icon={tab === "favorites" ? "heart" : "library"}
                    title={tab === "favorites" ? t("library.noFavorites") : t("library.noHistory")}
                    description={tab === "favorites" ? t("library.noFavoritesHint") : t("library.noHistoryHint")}
                    actionLabel={t("library.searchTracks")}
                    onAction={() => actions.openView("search")}
                />
            )}
        </div>
    );
}
