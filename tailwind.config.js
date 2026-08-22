/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        background: '#F8F3EA',
        card: '#FFFDFC',
        secondaryCard: '#F4EEE3',
        primaryGreen: '#526B57',
        secondaryGreen: '#7D8F78',
        gold: '#B9A06A',
        primaryText: '#26352C',
        secondaryText: '#6E716C',
        placeholder: '#AAA9A3',
        cream: {
          bg: '#F8F3EA',
          cardTop: '#FFFDFC',
          cardBottom: '#F4EEE3',
        },
        forest: {
          DEFAULT: '#526B57',
          soft: '#7D8F78',
          dark: '#26352C',
          light: '#F4EEE3',
        },
        ink: {
          DEFAULT: '#26352C',
          soft: '#6E716C',
          muted: '#AAA9A3',
        },
        coral: {
          DEFAULT: '#D97D6C',
          light: '#FCECE9',
        },
        dark: {
          bg: '#15201A',
          card: '#1E2B22',
          cardHighlight: '#27382D',
          primary: '#8FC49A',
          ink: '#EDEAE0',
          soft: '#A7B3A9',
        }
      },
      fontFamily: {
        naskh: ['"Noto Naskh Arabic"', 'Amiri', 'serif'],
        kufi: ['"Noto Kufi Arabic"', 'Tajawal', 'sans-serif'],
      }
    },
  },
  plugins: [],
}
