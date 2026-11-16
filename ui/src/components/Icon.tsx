export type IconName =
    | "home" | "search" | "library" | "music" | "play" | "pause" | "next" | "prev" | "heart" | "speaker" | "car"
    | "headphones" | "off" | "up" | "down" | "more" | "shuffle" | "repeat" | "back" | "close" | "trash" | "queue"
    | "image" | "settings" | "paperclip" | "plus" | "expand";

export function Icon({ name }: { name: IconName }) {
    if (name === "shuffle") {
        return (
            <svg className="icon-shuffle" viewBox="0 0 24 24" aria-hidden="true">
                <path d="M4 7.5h3.1c2.2 0 3.35 1.55 4.55 3.35l.7 1.05C13.55 13.7 14.7 15.5 17 15.5h3" />
                <path d="M17.2 11.9 21 15.5l-3.8 3.6" />
                <path d="M4 16.5h3.1c1.6 0 2.65-.85 3.55-2.05" />
                <path d="M12.35 9.55C13.55 7.85 14.7 7.5 17 7.5h4" />
                <path d="M17.2 3.9 21 7.5l-3.8 3.6" />
            </svg>
        );
    }

    return (
        <svg viewBox="0 0 24 24" aria-hidden="true">
            {name === "home" && <><path d="M3 11.5 12 4l9 7.5" /><path d="M5.5 10.5V20h5v-5h3v5h5v-9.5" /></>}
            {name === "search" && <><circle cx="11" cy="11" r="7" /><path d="m16 16 4 4" /></>}
            {name === "library" && <><path d="M6 4v16" /><path d="M11 6v14" /><path d="m16 5 3 14" /></>}
            {name === "music" && <><path d="M9 18V5l10-2v13" /><circle cx="7" cy="18" r="3" /><circle cx="17" cy="16" r="3" /></>}
            {name === "play" && <path d="M8 5v14l11-7z" className="fill" />}
            {name === "pause" && <><path d="M8 5h3v14H8z" className="fill" /><path d="M14 5h3v14h-3z" className="fill" /></>}
            {name === "next" && <><path d="m6 5 9 7-9 7z" className="fill" /><path d="M18 5v14" /></>}
            {name === "prev" && <><path d="m18 5-9 7 9 7z" className="fill" /><path d="M6 5v14" /></>}
            {name === "heart" && <path d="M20.5 8.5c0 5-8.5 10-8.5 10s-8.5-5-8.5-10A4.5 4.5 0 0 1 12 6a4.5 4.5 0 0 1 8.5 2.5z" />}
            {name === "speaker" && <><path d="M5 9v6h4l5 4V5L9 9z" /><path d="M17 9.5a4 4 0 0 1 0 5" /></>}
            {name === "car" && <><path d="M5 12 7 7h10l2 5" /><path d="M4 12h16v5H4z" /><circle cx="7" cy="17" r="1.5" /><circle cx="17" cy="17" r="1.5" /></>}
            {name === "headphones" && <><path d="M4 14v-2a8 8 0 0 1 16 0v2" /><path d="M4 14h4v6H4z" /><path d="M16 14h4v6h-4z" /></>}
            {name === "off" && <><circle cx="12" cy="12" r="8" /><path d="m7 7 10 10" /></>}
            {name === "up" && <path d="m6 15 6-6 6 6" />}
            {name === "down" && <path d="m6 9 6 6 6-6" />}
            {name === "more" && <><circle cx="12" cy="5" r="1" className="fill" /><circle cx="12" cy="12" r="1" className="fill" /><circle cx="12" cy="19" r="1" className="fill" /></>}
            {name === "repeat" && <><path d="M17 2 21 6l-4 4" /><path d="M3 11V9a3 3 0 0 1 3-3h15" /><path d="m7 22-4-4 4-4" /><path d="M21 13v2a3 3 0 0 1-3 3H3" /></>}
            {name === "back" && <path d="m15 18-6-6 6-6" />}
            {name === "close" && <><path d="M6 6l12 12" /><path d="M18 6 6 18" /></>}
            {name === "trash" && <><path d="M4 7h16" /><path d="M10 11v6" /><path d="M14 11v6" /><path d="M6 7l1 14h10l1-14" /><path d="M9 7V4h6v3" /></>}
            {name === "queue" && <><path d="M8 6h12" /><path d="M8 12h12" /><path d="M8 18h12" /><path d="M4 6h.01" /><path d="M4 12h.01" /><path d="M4 18h.01" /></>}
            {name === "image" && <><rect x="4" y="5" width="16" height="14" rx="2" /><circle cx="9" cy="10" r="1.5" /><path d="m7 17 4-4 3 3 2-2 3 3" /></>}
            {name === "paperclip" && <path d="m21.4 11.6-8.5 8.5a5 5 0 0 1-7.1-7.1l9-9a3.3 3.3 0 0 1 4.7 4.7l-9 9a1.65 1.65 0 0 1-2.35-2.35l8.15-8.15" />}
            {name === "settings" && <><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.7 1.7 0 0 0 .34 1.88l.04.04a2 2 0 0 1-2.83 2.83l-.04-.04A1.7 1.7 0 0 0 15 19.4a1.7 1.7 0 0 0-1 1.55V21a2 2 0 0 1-4 0v-.05a1.7 1.7 0 0 0-1-1.55 1.7 1.7 0 0 0-1.88.34l-.04.04a2 2 0 0 1-2.83-2.83l.04-.04A1.7 1.7 0 0 0 4.6 15a1.7 1.7 0 0 0-1.55-1H3a2 2 0 0 1 0-4h.05A1.7 1.7 0 0 0 4.6 9a1.7 1.7 0 0 0-.34-1.88l-.04-.04a2 2 0 0 1 2.83-2.83l.04.04A1.7 1.7 0 0 0 9 4.6a1.7 1.7 0 0 0 1-1.55V3a2 2 0 0 1 4 0v.05a1.7 1.7 0 0 0 1 1.55 1.7 1.7 0 0 0 1.88-.34l.04-.04a2 2 0 0 1 2.83 2.83l-.04.04A1.7 1.7 0 0 0 19.4 9a1.7 1.7 0 0 0 1.55 1H21a2 2 0 0 1 0 4h-.05A1.7 1.7 0 0 0 19.4 15z" /></>}
            {name === "plus" && <><path d="M12 5v14" /><path d="M5 12h14" /></>}
            {name === "expand" && <><path d="M14 4h6v6" /><path d="M10 20H4v-6" /><path d="M20 4l-7 7" /><path d="M4 20l7-7" /></>}
        </svg>
    );
}
