import { useFiveFY } from "../state/store";
import { HomeView } from "../views/HomeView";
import { LibraryView } from "../views/LibraryView";
import { PlayerView } from "../views/PlayerView";
import { PlaylistView } from "../views/PlaylistView";
import { ProfileView } from "../views/ProfileView";
import { SearchView } from "../views/SearchView";

/** Renders the current view; both shells share it. */
export function CurrentView({ panel = false }: { panel?: boolean }) {
    const { view } = useFiveFY();

    switch (view) {
        case "search":
            return <SearchView />;
        case "library":
            return <LibraryView />;
        case "player":
            return <PlayerView />;
        case "playlist":
            return <PlaylistView />;
        case "profile":
            return <ProfileView />;
        default:
            return <HomeView showHeader={!panel} />;
    }
}
