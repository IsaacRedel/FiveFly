import { Component, StrictMode, useEffect, type ReactNode } from "react";
import { createRoot, type Root } from "react-dom/client";
import { fetchNui } from "../bridge/nui";
import { PanelShell } from "../shells/PanelShell";
import { FiveFYProvider, useFiveFY } from "../state/store";
import "../styles/index.css";

const container = document.getElementById("panel-root") as HTMLElement;
let root: Root | null = null;
let reloadData: (() => void) | null = null;

function setVisible(visible: boolean) {
    container.classList.toggle("is-open", visible);
}

function closePanel() {
    setVisible(false);
    fetchNui("panel.close");
}

/** If rendering fails, release focus instead of leaving an empty captured screen; reopening retries. */
class PanelErrorBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
    state = { failed: false };

    static getDerivedStateFromError() {
        return { failed: true };
    }

    componentDidCatch(error: unknown) {
        console.error("[fivefy] panel crashed", error);
        closePanel();
    }

    retry() {
        this.setState({ failed: false });
    }

    render() {
        return this.state.failed ? null : this.props.children;
    }
}

let boundary: PanelErrorBoundary | null = null;

/** Exposes the store reload so a reopened panel shows changes made from the phone meanwhile. */
function ReloadBinding() {
    const { actions } = useFiveFY();
    const reload = actions.reload;

    useEffect(() => {
        reloadData = reload;
        return () => {
            reloadData = null;
        };
    }, [reload]);

    return null;
}

export function openPanel() {
    if (root) {
        boundary?.retry();
        reloadData?.();
    } else {
        root = createRoot(container);
        root.render(
            <StrictMode>
                <PanelErrorBoundary ref={(instance) => { boundary = instance; }}>
                    <FiveFYProvider origin="panel">
                        <ReloadBinding />
                        <PanelShell onClose={closePanel} />
                    </FiveFYProvider>
                </PanelErrorBoundary>
            </StrictMode>
        );
    }

    setVisible(true);
}

export function hidePanel() {
    setVisible(false);
}
