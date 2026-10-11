# ESX Legacy HUD web

Interfaz SolidJS y Vite. Consulta el README del recurso para configuración, instalación y referencias.

- `npm ci`: instalar dependencias.
- `npm run dev -- --host 127.0.0.1`: iniciar vista previa en `http://127.0.0.1:3000/?preview`.
- `npm test`: validación del modelo de preferencias y valores del HUD.
- `npm run build`: compilar `dist` para FiveM.
- `npm run test:ui`: pruebas de navegador con servidor local y Chromium disponibles.

Código activo: `src/App.jsx`, `src/hud/`, `src/Utils/Nui.js` y `src/index.css`. Los componentes del diseño anterior se conservan como referencia y no forman parte del bundle.
