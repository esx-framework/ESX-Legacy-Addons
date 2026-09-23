const paths = {
    heart: "M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8Z",
    shield: "M12 3 3 7v5c0 5 9 9 9 9s9-4 9-9V7l-9-4Z",
    food: "M3 11h18M3 15h18M5 18h14l1-3H4l1 3ZM4 8c0-7 16-7 16 0H4Z",
    drop: "M12 2S5 10 5 15a7 7 0 0 0 14 0c0-5-7-13-7-13Z",
    bolt: "m13 2-9 12h7l-1 8 10-13h-7l1-7Z",
    lungs: "M10 4v9l-4 3M14 4v9l4 3M8 7C3 7 2 17 4 20c1 1 6 0 6-3V9M16 7c5 0 6 10 4 13-1 1-6 0-6-3V9",
    mic: "M9 5a3 3 0 0 1 6 0v7a3 3 0 0 1-6 0V5ZM5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8",
    radio: "M6 7h12v14H6V7ZM8 7l8-5M9 11h6M9 16h6M9 18h6",
    pin: "M20 10c0 6-8 12-8 12S4 16 4 10a8 8 0 0 1 16 0ZM15 10a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z",
    wallet: "M3 6h16v4H3V6Zm0 4v10h18V10H3Zm13 4h5v3h-5v-3Z",
    bank: "m3 8 9-5 9 5H3ZM5 11v7M10 11v7M14 11v7M19 11v7M3 21h18",
    work: "M8 7V4h8v3M3 8h18v12H3V8Zm0 5 9 3 9-3M12 13v4",
    people: "M15 7a3 3 0 1 1-6 0 3 3 0 0 1 6 0ZM5 21v-3a7 7 0 0 1 14 0v3M19 4a3 3 0 0 1 0 6",
    fuel: "M4 21V3h10v18M2 21h14M4 10h10M17 5l4 4v9a2 2 0 0 1-4 0v-5h-3",
    engine: "M7 7h9l3 4h3v7h-3l-3 3H7l-3-4V9h3V7ZM8 3h7M11 3v4M1 11v6",
    belt: "M9 4a3 3 0 1 0 6 0 3 3 0 0 0-6 0ZM8 10l-2 8h12l-2-8M5 22l2-4M19 22l-2-4M3 10l18 10",
    light: "M14 4v16c-12 0-12-16 0-16ZM17 6h5M17 10h5M17 14h5M17 18h5",
    lock: "M7 10V7a5 5 0 0 1 10 0v3M5 10h14v11H5V10ZM12 14v3",
    cruise: "M4 19a10 10 0 1 1 16 0M12 14l6-7M5 12h2M12 4v2M17 12h2M11 19h2",
    settings: "M4 7h16M4 17h16M9 4v6M15 14v6",
    close: "m6 6 12 12M6 18 18 6",
    arrow: "M19 12H5m7-7-7 7 7 7",
    check: "m5 12 4 4L19 6",
    eye: "M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Zm13 0a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z",
    screen: "M3 4h18v13H3V4ZM8 21h8M12 17v4",
    warning: "m12 3 10 18H2L12 3Zm0 6v5M12 17v1",
};
export default function Icon(props) {
    return (
        <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d={paths[props.name] || paths.screen} />
        </svg>
    );
}
