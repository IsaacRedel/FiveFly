import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { setUiOrigin } from "./bridge/nui";
import { PhoneShell } from "./shells/PhoneShell";
import { FiveFYProvider } from "./state/store";
import "./styles/index.css";

setUiOrigin("phone");

createRoot(document.getElementById("root") as HTMLElement).render(
    <StrictMode>
        <FiveFYProvider origin="phone">
            <PhoneShell />
        </FiveFYProvider>
    </StrictMode>
);
