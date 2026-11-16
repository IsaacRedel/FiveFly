import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { setUiOrigin } from "./bridge/nui";
import { PhoneShell } from "./shells/PhoneShell";
import { FiveFlyProvider } from "./state/store";
import "./styles/index.css";

setUiOrigin("phone");

createRoot(document.getElementById("root") as HTMLElement).render(
    <StrictMode>
        <FiveFlyProvider origin="phone">
            <PhoneShell />
        </FiveFlyProvider>
    </StrictMode>
);
