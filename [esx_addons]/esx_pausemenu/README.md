# esx_pausemenu

Nuevo pause menu NUI para **ESX Legacy 1.16.0**, maquetado a partir del boceto suministrado y preparado para integrarse con el release `1.16.0` de `esx_core` / `ESX-Legacy-Addons`.

## Integración ESX 1.16.0

El recurso sigue los patrones que usa el release indicado:

- Importa `@esx_lib/imports.lua` y `@es_extended/imports.lua`.
- Usa `xLib.nui.open / close / register / send` para el ciclo NUI.
- Usa `ESX.RegisterServerCallback` / `ESX.TriggerServerCallback` para datos del jugador.
- Obtiene `bank`, `money`, trabajo y playtime mediante la API de `xPlayer`.
- Usa `xLib.colors.getESXTheme()` y `xLib.colors.*`, por lo que respeta los ConVars de tema de ESX.
- PEOPLE abre `esx_scoreboard` mediante el comando configurable si dicho recurso está iniciado.

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
3. Edita `config.lua` y configura `Config.Links.discord`, `Config.Links.rules` y `Config.Links.store`.
4. Reinicia el recurso/servidor.

El script intercepta `ESC` y `P` cuando el jugador ESX está cargado. MAP abre el mapa nativo de GTA, SETTINGS abre el pause menu nativo y LEAVE SERVER desconecta únicamente al jugador que lo pulsa.

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

- La pantalla central prioriza tres niveles: accion principal, identidad del personaje y ubicacion actual.
- El avatar se muestra con iniciales generadas desde el nombre del jugador. La interfaz usa fondos solidos con transparencia; el mapa se carga desde `web/assets` sin dependencias web externas en tiempo de juego.
- El diseño usa un lienzo de referencia de 1536×1024 y se escala manteniendo proporción para conservar la maquetación del mockup.
- Para ver el front-end fuera de FiveM abre `web/index.html?preview=1` en Chromium.
- Los textos de la interfaz están en `locales/` (en, fr, de, es, it, nl, pl) y siguen el ConVar `esx:locale`.
