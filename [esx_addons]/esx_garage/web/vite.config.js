import { defineConfig } from 'vite'
import tailwindcss from '@tailwindcss/vite'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path'

export default defineConfig({
  plugins: [vue(), tailwindcss()],
  base: './',
  build: {
    outDir: '../nui',
    emptyOutDir: true,
    assetsDir: 'assets',
    rollupOptions: {
      output: {
        entryFileNames: 'js/[name].js',
        chunkFileNames: 'js/[name].js',
        assetFileNames: (assetInfo) => {
          const ext = assetInfo.name ? assetInfo.name.split('.').pop() : ''
          if (/ttf|otf|woff2?|eot/i.test(ext)) return 'fonts/[name][extname]'
          if (/png|jpe?g|gif|svg|webp|ico/i.test(ext)) return 'img/[name][extname]'
          if (/css/i.test(ext)) return 'css/[name][extname]'
          return 'assets/[name][extname]'
        }
      }
    }
  },
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src')
    }
  }
})
