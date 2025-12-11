// vite.config.js
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import tailwindcss from '@tailwindcss/vite'


const HMR_HOST = process.env.VITE_HMR_HOST || 'localhost';
const HMR_PORT = Number(process.env.VITE_HMR_PORT || 5173);
const VITE_PORT = Number(process.env.VITE_PORT || 5173);
const PROXY_TARGET = process.env.VITE_PROXY_TARGET || 'http://localhost:61000';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
        }),
        tailwindcss(),
    ],
    server: {
        host: '0.0.0.0',
        port: VITE_PORT,
        hmr: {
            protocol: 'ws',
            host: HMR_HOST,
            port: HMR_PORT,
            clientPort: HMR_PORT,
        },
        proxy: {
            '^/(storage|images|css|js|assets)': {
                target: PROXY_TARGET,
                changeOrigin: true,
                secure: false,
            },
        },
    },
});