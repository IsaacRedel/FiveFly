import { useRef, type MouseEvent, type PointerEvent } from "react";

const DRAG_THRESHOLD = 12;

/** Lets a horizontal list scroll by dragging with the mouse (NUI has no touch), without firing clicks after a drag. */
export function useHorizontalDragScroll<T extends HTMLElement>() {
    const ref = useRef<T | null>(null);
    const drag = useRef({ active: false, startX: 0, scrollLeft: 0, moved: false });

    function stop(pointerId?: number) {
        const element = ref.current;
        drag.current.active = false;
        element?.classList.remove("is-dragging");

        if (element && pointerId !== undefined) {
            element.releasePointerCapture?.(pointerId);
        }
    }

    return {
        ref,
        onPointerDown(event: PointerEvent<T>) {
            const element = ref.current;
            if (!element) return;

            drag.current = { active: true, startX: event.clientX, scrollLeft: element.scrollLeft, moved: false };
            element.setPointerCapture?.(event.pointerId);
        },
        onPointerMove(event: PointerEvent<T>) {
            const element = ref.current;
            if (!element || !drag.current.active) return;

            const delta = event.clientX - drag.current.startX;

            if (Math.abs(delta) > DRAG_THRESHOLD) {
                drag.current.moved = true;
                element.classList.add("is-dragging");
                element.scrollLeft = drag.current.scrollLeft - delta;
            }
        },
        onPointerUp(event: PointerEvent<T>) {
            stop(event.pointerId);
        },
        onPointerCancel(event: PointerEvent<T>) {
            stop(event.pointerId);
        },
        onPointerLeave() {
            stop();
        },
        onClickCapture(event: MouseEvent<T>) {
            if (!drag.current.moved) return;

            event.preventDefault();
            event.stopPropagation();
            drag.current.moved = false;
        }
    };
}
