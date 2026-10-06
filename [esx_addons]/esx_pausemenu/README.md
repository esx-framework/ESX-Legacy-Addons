# esx_pausemenu

Nuevo pause menu NUI para **ESX Legacy 1.16.0**, maquetado a partir del boceto suministrado y preparado para integrarse con el release `1.16.0` de `esx_core` / `ESX-Legacy-Addons`.

## Integración ESX 1.16.0

El recurso sigue los patrones que usa el release indicado:

- Importa `@esx_lib/imports.lua` y `@es_extended/imports.lua`.
- Usa `xLib.nui.open / close / register / send` para el ciclo NUI.
- Usa `ESX.RegisterServerCallback` / `ESX.TriggerServerCallback` para datos del jugador.
- Obtiene nombre del personaje, género, `bank`, `money`, trabajo y playtime mediante la API de `xPlayer`. El nombre de usuario se muestra por separado en la cabecera.
- El ping se obtiene desde el servidor y la calle desde la posición actual del personaje.
- Usa `xLib.colors.getESXTheme()` y `xLib.colors.*`, por lo que respeta los ConVars de tema de ESX.
- El indicador de jugadores online abre `esx_scoreboard` mediante el comando configurable si dicho recurso está iniciado.

## Paleta ESX usada

Los defaults de `esx_lib` en la rama 1.16.0 son:

- Brand: `#FB9B04`
- Darkest: `#161616`
- Dark: `#252525`
- Mid: `#383838`
- Light: `#969696`
- Lightest: `#F2F2F2`

El recurso no fuerza esos valores si el servidor ya redefine los ConVars de ESX UI; los lee en tiempo real desde `xLib.colors`.

## Instalación

1. Copia la carpeta `esx_pausemenu` dentro de tu bloque de recursos, por ejemplo `resources/[core]/esx_pausemenu`.
2. Si ya usas `ensure [core]`, no necesitas una línea adicional. En caso contrario añade `ensure esx_pausemenu` después de `esx_lib` y `es_extended`.
3. Edita `config.lua` y configura `Config.Links.discord` y `Config.Links.rules`. `Config.Links.store` añade un acceso opcional desde Novedades.
4. Reinicia el recurso/servidor.

El script intercepta `ESC` y `P` cuando el jugador ESX está cargado. Jugar vuelve al juego, el panel del mapa abre el mapa nativo de GTA, Ajustes abre el pause menu nativo y Salir desconecta únicamente al jugador que lo pulsa tras confirmar.

## Novedades

El botón Novedades abre los avisos de `Config.News`. La lista vacía muestra un mensaje y el acceso a Discord. Puedes añadir avisos así, con los más recientes primero:

```lua
Config.News = {
    {
        title = "Título del aviso",
        body = "Texto del aviso. Se muestra como texto plano.",
        date = "27 SEP 2026"
    }
}
```

La fecha se muestra tal como la configures. La interfaz admite hasta 20 avisos y permite desplazarse dentro del diálogo.

## Tema opcional por ConVars

`esx_lib` 1.16.0 permite redefinir el tema. Si ya lo haces en tu servidor, `esx_pausemenu` lo heredará. Ejemplo:

```cfg
setr esx:brand-color "#FB9B04"
setr esx:darkest-color "#161616"
setr esx:dark-color "#252525"
setr esx:mid-color "#383838"
setr esx:light-color "#969696"
setr esx:lightest-color "#F2F2F2"
setr esx:ui:primaryColor "#FB9B04"
setr esx:ui:secondaryColor "#252525"
setr esx:ui:backgroundColor "#161616"
setr esx:ui:accentColor "#383838"
```

## Notas

- La estructura incluye cabecera de estado, navegación lateral, normas, bienvenida con fotografía, ficha del personaje, mapa y Discord.
- La ficha muestra el nombre completo y los datos del personaje, sin ID ni iniciales decorativas. Los fondos son sólidos, sin degradados. La fotografía no tiene marca de agua y se presenta en un marco panorámico sin etiquetas superpuestas. Los recursos visuales se cargan desde `web/assets` sin dependencias externas durante el juego.
- El diseño usa un lienzo de referencia de 1600×900 y se escala manteniendo la proporción. En pantallas con otra proporción se centra sin deformar los paneles.
- Para ver el front-end fuera de FiveM usa la vista previa HTTP con `?preview=1`. Detecta el idioma del navegador; `&lang=es` o `&lang=en` permiten revisar un idioma concreto. Sus datos son ejemplos y sus botones simulan las acciones del juego. Al editar las traducciones Lua, ejecuta `node tools/build-pausemenu-locales.mjs` desde la raíz del repo para actualizar el catálogo de la vista previa.
- Las flechas y Tab permiten navegar. Los diálogos retienen el foco y Escape los cierra, devolviendo el foco al botón anterior.
- En FiveM el idioma sigue `esx:locale`, con la configuración de ESX como respaldo (incluido el idioma de txAdmin cuando ESX lo usa). Se actualiza al abrir el menú si cambia el idioma. Los textos están en `locales/` (en, fr, de, es, it, nl, pl), y los idiomas no disponibles usan el respaldo inglés de ESX. El idioma del navegador solo se usa fuera del juego en la vista previa.
- Los créditos de los recursos visuales están en `web/assets/SOURCES.md`.
