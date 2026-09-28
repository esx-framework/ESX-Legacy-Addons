# Pause menu visual assets

- `city-skyline.jpg`: GTA V screenshot without a watermark, Rockstar Games. Source: [Shacknews, GTA 5 had more players in 2020 than any previous year](https://www.shacknews.com/article/122680/gta-5-had-more-players-in-2020-than-any-previous-year). Image: https://d1lss44hh2trtw.cloudfront.net/assets/editorial/2021/02/gta-5.jpg
- `icons/*.svg` except `discord.svg`: ESX Legacy UI icon pack supplied by the user, from `esx_legacy_icons_figma/esx_legacy_icons_svg`. Original shapes are used as CSS masks to inherit the interface colors.
- `icons/discord.svg`: original black Discord symbol from [Discord's official brand assets](https://discord.com/branding). Asset: https://cdn.prod.website-files.com/6257adef93867e50d84d30e2/66e3d8014ea898f3a4b2156c_Symbol.svg
- `fonts/Poppins-*.ttf`: Poppins, reused from the existing `esx_joblisting/web/assets` font assets.
- `esx-logo.png` and `gtavmap.webp`: existing pause menu assets, retained.

The interface loads these assets locally; no image, font or icon requests are made to external services during gameplay.
