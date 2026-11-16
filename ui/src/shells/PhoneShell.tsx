import { BottomNav, MiniPlayer, Toasts } from "../components/chrome";
import { Overlays } from "../sheets/Overlays";
import { useFiveFly } from "../state/store";
import { CurrentView } from "./views";

/** Compact layout used inside the lb-phone app frame. */
export function PhoneShell() {
    const { view } = useFiveFly();

    return (
        <main className="fivefly-app is-phone">
            <section key={view} className={`fivefly-screen fivefly-screen--${view}`}>
                <CurrentView />
            </section>

            <Toasts />
            {view !== "player" && <MiniPlayer />}
            <BottomNav />
            <Overlays />
        </main>
    );
}
