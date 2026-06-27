/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        'sidebar-blue': '#1e3a5f',
        'sidebar-blue-light': '#2a4d7f',
        'clinical-red': '#dc2626',
        'clinical-amber': '#d97706',
        'clinical-green': '#16a34a',
      },
    },
  },
  plugins: [],
};
