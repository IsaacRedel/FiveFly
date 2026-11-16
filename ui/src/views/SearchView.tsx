import { Artwork, EmptyState, TrackList } from "../components/common";
import { Icon } from "../components/Icon";
import { useT } from "../i18n";
import { useFiveFY } from "../state/store";

function SocialResults() {
    const t = useT();
    const { socialResults, actions } = useFiveFY();

    if (socialResults.profiles.length === 0 && socialResults.playlists.length === 0) {
        return null;
    }

    return (
        <div className="social-result-list">
            {socialResults.profiles.length > 0 && (
                <section>
                    <h2>{t("search.profiles")}</h2>
                    {socialResults.profiles.slice(0, 4).map((profile) => (
                        <button className="social-profile-row" type="button" key={profile.userId} onClick={() => actions.openProfile(profile.userId)}>
                            <Artwork image={profile.avatar || profile.publicPlaylists[0]?.cover || ""} size="small" />
                            <span>
                                <strong>{profile.name}</strong>
                                <em>{profile.bio || t("search.followers", { count: profile.followerCount })}</em>
                            </span>
                            <Icon name="next" />
                        </button>
                    ))}
                </section>
            )}

            {socialResults.playlists.length > 0 && (
                <section>
                    <h2>{t("search.publicPlaylists")}</h2>
                    {socialResults.playlists.slice(0, 4).map((playlist) => (
                        <button className="social-profile-row" type="button" key={playlist.id} onClick={() => playlist.shareCode && actions.importPlaylist(playlist.shareCode)}>
                            <Artwork image={playlist.cover || ""} size="small" />
                            <span>
                                <strong>{playlist.name}</strong>
                                <em>{playlist.ownerName || t("search.publicPlaylist")} · {t("common.tracks", { count: playlist.trackCount })}</em>
                            </span>
                            <Icon name="plus" />
                        </button>
                    ))}
                </section>
            )}
        </div>
    );
}

export function SearchView() {
    const t = useT();
    const { query, isSearching, searchResults, socialResults, data, actions } = useFiveFY();
    const total = searchResults.length + socialResults.profiles.length + socialResults.playlists.length;

    return (
        <div className="view-stack search-view">
            <header className="sticky-head">
                <h1>{t("search.title")}</h1>
                <label className="search-box">
                    <Icon name="search" />
                    <input value={query} onChange={(event) => actions.setQuery(event.target.value)} placeholder={t("search.placeholder")} autoFocus />
                </label>
            </header>

            {query.trim().length === 0 ? (
                <EmptyState icon="search" title={t("search.startTitle")} description={t("search.startHint")} />
            ) : isSearching ? (
                <div className="result-list">
                    {[0, 1, 2, 3, 4].map((item) => <div className="skeleton-row" key={item} />)}
                </div>
            ) : total > 0 ? (
                <>
                    <div className="search-results-head">
                        <span>{t("search.results", { count: total })}</span>
                        <button type="button" onClick={() => actions.setQuery("")}>{t("common.clear")}</button>
                    </div>
                    <SocialResults />
                    {searchResults.length > 0 && (
                        <TrackList
                            tracks={searchResults}
                            favorites={data.library.favorites}
                            onPlay={(track) => actions.play(track, searchResults)}
                            onFavorite={actions.toggleTrackFavorite}
                            onMore={actions.openTrackActions}
                        />
                    )}
                </>
            ) : (
                <EmptyState
                    icon="search"
                    title={t("search.noResults")}
                    description={t("search.noResultsHint", { query })}
                    actionLabel={t("search.clearSearch")}
                    onAction={() => actions.setQuery("")}
                />
            )}
        </div>
    );
}
