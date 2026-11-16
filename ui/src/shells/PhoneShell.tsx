import { BottomNav, MiniPlayer, Toasts } from "../components/chrome";
import { Overlays } from "../sheets/Overlays";
import { useFiveFY } from "../state/store";
import { CurrentView } from "./views";

/** Compact layout used inside the lb-phone app frame. */
export function PhoneShell() {
    const { view } = useFiveFY();

    return (
        <main className="fivefy-app is-phone">
            <section key={view} className={`fivefy-screen fivefy-screen--${view}`}>
                <CurrentView />
            </section>

            <Toasts />
            {view !== "player" && <MiniPlayer />}
            <BottomNav />
            <Overlays />
        </main>
    );
}
