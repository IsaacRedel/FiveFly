import { Artwork } from "../components/common";
import { Icon } from "../components/Icon";
import { useT } from "../i18n";
import { useFiveFly } from "../state/store";

export function ProfileView() {
    const t = useT();
    const { activeProfile: profile, data, currentTrack, isPlaying, actions } = useFiveFly();
    const isOwn = profile.userId === data.profile.userId;
    const session = data.library.friendsListening.find((item) => item.userId === profile.userId) || null;
    const liveTrack = isOwn ? currentTrack : session?.currentTrack || null;
    const heroImage = profile.avatar || profile.publicPlaylists[0]?.cover || liveTrack?.thumbnail || "";

    return (
        <div className="view-stack profile-view">
            <header className="profile-topbar">
                <button className="icon-button muted" type="button" onClick={() => actions.goBack()} aria-label={t("common.back")}>
                    <Icon name="back" />
                </button>
                <span>{t("profile.title")}</span>
                <span aria-hidden="true" />
            </header>

            <section className="profile-hero">
                <div className="profile-hero-art">
                    <Artwork image={heroImage} size="large" />
                </div>
                <span className="profile-kicker">{t("profile.kicker")}</span>
                <h1>{profile.name}</h1>
                <p>{profile.bio || (isOwn ? t("profile.ownEmptyBio") : t("profile.emptyBio"))}</p>

                <div className="profile-stats-row">
                    <span><strong>{profile.publicPlaylists.length}</strong> {t("profile.playlists")}</span>
                    <span><strong>{profile.followerCount}</strong> {t("profile.followers")}</span>
                    <span><strong>{profile.followingCount}</strong> {t("profile.following")}</span>
                </div>

                <div className="profile-actions">
                    {isOwn ? (
                        <button className="primary-sheet-button compact" type="button" onClick={() => actions.setSheet({ type: "profileEdit" })}>
                            {t("profile.edit")}
                        </button>
                    ) : (
                        <button className={profile.following ? "primary-sheet-button compact secondary" : "primary-sheet-button compact"} type="button" onClick={() => actions.toggleFollow(profile)}>
                            {profile.following ? t("profile.followingButton") : t("profile.follow")}
                        </button>
                    )}
                </div>
            </section>

            {liveTrack && profile.showActivity !== false && (
                <section className="profile-now-card">
                    <div>
                        <span>{isOwn ? t("profile.youAreListening") : t("profile.listeningNow")}</span>
                        <strong>{liveTrack.title}</strong>
                        <em>{liveTrack.author || t("common.unknownArtist")}</em>
                    </div>
                    <button
                        className={isPlaying && isOwn ? "profile-now-play active" : "profile-now-play"}
                        type="button"
                        onClick={() => (isOwn ? actions.openView("player") : session && actions.joinSession(session.source))}
                        aria-label={t("profile.openPlayer")}
                    >
                        <Icon name={isPlaying && isOwn ? "pause" : "play"} />
                    </button>
                </section>
            )}

            <section className="profile-playlists">
                <div className="section-title-row">
                    <div>
                        <span>{isOwn ? t("profile.shared") : t("profile.fromProfile")}</span>
                        <h2>{t("profile.publicPlaylists")}</h2>
                    </div>
                </div>

                {profile.publicPlaylists.length > 0 ? (
                    <div className="profile-public-list">
                        {profile.publicPlaylists.map((playlist) => (
                            <button
                                className="social-profile-row"
                                type="button"
                                key={playlist.id}
                                onClick={() => (isOwn ? actions.openPlaylist(playlist.id) : playlist.shareCode && actions.importPlaylist(playlist.shareCode))}
                            >
                                <Artwork image={playlist.cover || ""} size="small" />
                                <span>
                                    <strong>{playlist.name}</strong>
                                    <em>{t("common.tracks", { count: playlist.trackCount })}</em>
                                </span>
                                <Icon name={isOwn ? "library" : "plus"} />
                            </button>
                        ))}
                    </div>
                ) : (
                    <div className="discovery-empty">
                        <strong>{t("profile.noPublic")}</strong>
                        <span>{isOwn ? t("profile.noPublicOwnHint") : t("profile.noPublicHint")}</span>
                    </div>
                )}
            </section>
        </div>
    );
}
