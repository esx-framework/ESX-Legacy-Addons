# ESX Custom Props

A centralized resource for all custom props used across ESX resources.

## Purpose
This resource manages all custom props to avoid conflicts and provide a single location for prop management.

## Current Props
- **Handcuffs** - Used by police job for handcuffing mechanics

## Adding New Props
1. Place `.ydr` and `.ytyp` files in the `stream/` folder
2. Add the `.ytyp` file to the `files` section in `fxmanifest.lua`
3. Add a `data_file 'DLC_ITYP_REQUEST'` entry for the `.ytyp` file
4. Update this README with the new prop information

## Dependencies
Any resource using these props should add `esx_custom_props` as a dependency in their `fxmanifest.lua`.