/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,jsx,ts,tsx}"],
  theme: {
    extend: {
      backgroundImage: {
        "ammo-container-background":
          "linear-gradient(270deg, rgba(255, 255, 255, 0.15) -0.79%, rgba(255, 255, 255, 0) 107.59%)",
      },
      keyframes: {
        blinker: {
          "50%": { opacity: "0" },
        },
      },
      animation: {
        blinker: "blinker 1s step-start infinite",
      },
    },
  },
  plugins: [],
};
