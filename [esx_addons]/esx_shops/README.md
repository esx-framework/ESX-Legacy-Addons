# ESX Shops

A modern, performance-optimized shop system for ESX Legacy servers with a sleek NUI interface built on Svelte 5.

![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)
![ESX](https://img.shields.io/badge/ESX-Legacy-success.svg)
![Svelte](https://img.shields.io/badge/Svelte-5-FF3E00?logo=svelte&logoColor=white)

## What This Does

ESX Shops replaces the default shop system with a fast, modern interface that doesn't make your players wait. Clean UI, no lag, and actually works the way you'd expect a shop to work.

**Key Features:**
- Modern Svelte 5 UI with smooth animations
- Dynamic tax system with job-based exemptions
- Performance-optimized client
- Server-side validation prevents all common exploits
- Supports both ESX and ox_inventory
- Fully configurable categories and items
- Theme integration via ESX convars

## Preview

The UI adapts to your server's ESX theme colors automatically. Items are organized by categories with search functionality. Tax calculations are transparent - players see exactly what they're paying.

## Installation

1. **Download** and place `esx_shops` in your resources folder
2. **Build the UI:**
   ```bash
   cd esx_shops/web
   npm install
   npm run build
   ```
3. **Add to server.cfg:**
   ```
   ensure esx_shops
   ```
4. **Configure** in `config.lua` (see below)

## Configuration

### Basic Setup

```lua
-- Inventory system
Config.Inventory = 'esx' -- or 'ox_inventory'

-- Tax settings
Config.TaxRate = 0.19 -- 19% VAT
Config.EnableTaxCollection = false -- Collect to society account?
Config.TaxSocietyAccount = 'society_government'

-- Job exemptions
Config.EnableTaxExemptions = false
Config.TaxExemptJobs = {
    'police',
    'ambulance',
    'government'
}
```

### Adding Shops

Each shop needs items, categories (optional), and locations:

```lua
Config.Zones = {
    YourShop = {
        Items = {
            {
                name = "bread",
                label = "Bread",
                price = 15,
                category = "food",
                image = "https://your-cdn.com/bread.png"
            }
        },
        Categories = {
            {id = "food", label = "Food", icon = "fa-solid fa-burger"}
        },
        Pos = {
            vector3(373.8, 325.8, 103.5)
        },
        Size = 0.8,
        Type = 59,
        Color = 25,
        ShowBlip = true,
        ShowMarker = true
    }
}
```

**Icons:** Use [FontAwesome 6](https://fontawesome.com/icons) class names (e.g., `fa-solid fa-burger`)

**Images:** You have three options for item images:
1. **CDN URLs:** `https://your-cdn.com/bread.png`
2. **NUI URLs (internal resources):** `nui://ox_inventory/web/images/bread.png`
3. **No image:** Leave it out - items work fine without them

Example using ox_inventory images:
```lua
{
    name = "bread",
    label = "Bread",
    price = 15,
    category = "food",
    image = "nui://ox_inventory/web/images/bread.png"
}
```

## What's Good

**Performance:**
- Client-side marker drawing is distance-based (only < 50 units)
- Nearby shop cache updates every 500ms, not every frame
- Dynamic sleep timers based on player distance
- Numeric loops instead of iterators where it matters

**Security:**
- All prices validated server-side
- Rate limiting (500ms between purchases)
- Quantity limits (max 999 per item)
- Inventory checks before money deduction
- No possibility for price manipulation or duplication

**User Experience:**
- Loads instantly, no frame drops
- Tax breakdown in checkout (players know what they're paying)
- ESX theme integration
- Search and category filters
- Responsive design scales to any resolution

## What's Not

**Limitations:**
- No stock/quantity limits per shop (infinite inventory)
- No job-restricted shops (anyone can buy from anywhere)
- No shop opening hours
- No shopkeeper NPCs
- Tax system requires `esx_addonaccount` if collection is enabled

These aren't bugs - they're design decisions. The script does shops, not roleplay mechanics. If you need job restrictions or stock management, fork it.

## Tax System Explained

The tax system is opt-in and configurable:

**Disabled** (`EnableTaxExemptions = false`):
- Everyone pays the same tax rate
- No special messages

**Enabled** (`EnableTaxExemptions = true`):
- Jobs in `TaxExemptJobs` pay 0% tax
- Exempt players see "⭐ Thanks for your service!" message
- Tax is calculated from gross prices (price includes tax)

**Tax Collection** (`EnableTaxCollection = true`):
- Requires `esx_addonaccount` resource
- Tax deposits to configured society account
- Logs warning if society account doesn't exist

**Example:**
```
Item: $100 (gross price with 19% tax)
Net:  $84.03
Tax:  $15.97
---
Police (exempt): Pays $84.03
Civilian: Pays $100.00
```

## Development

**UI Stack:**
- Svelte 5 (with runes)
- TypeScript
- Vite
- Terser (minification)

**Build Commands:**
```bash
cd web

# Development (auto-rebuild)
npm run dev:game

# Production build
npm run build

# Type checking
npm run check:strict
```

**File Structure:**
```
esx_shops/
├── client/main.lua          # Client logic
├── server/main.lua          # Server validation
├── shared/types.lua         # Type definitions
├── config.lua               # Configuration
├── web/
│   ├── src/
│   │   ├── components/      # Svelte components
│   │   ├── stores/          # State management
│   │   ├── utils/           # NUI helpers
│   │   └── App.svelte       # Root component
│   └── dist/                # Built files (created by npm run build)
└── fxmanifest.lua
```

## Common Issues

**"NUI not ready yet" on first use:**
- This is normal on resource start
- Just press E again after 1-2 seconds
- The UI needs time to initialize

**Images not loading:**
- Check your CDN CORS headers
- Use HTTPS for image URLs
- Test URLs in browser first

**Tax not collecting:**
- Verify `esx_addonaccount` is running
- Check society account exists in database
- Look for console warnings

**Shop won't open:**
- Check F8 console for errors
- Verify web/dist folder exists and has files
- Rebuild UI: `cd web && npm run build`

## Performance Notes

On a typical server with 64 players:
- Client: ~0.01ms average frame time
- Server: Negligible (callbacks only)
- Network: ~2KB per shop open

Tested with 50+ shops on map - no performance degradation.

## Credits

Built for ESX Legacy servers. Uses ox_lib for UI utilities (optional). Tax system inspired by real-world VAT calculations.

---

**Want to contribute?** PRs welcome. Keep it clean, keep it fast, and don't break the security model.

**Found a bug?** Open an issue with reproduction steps. "It doesn't work" isn't helpful.

**Need support?** Read the docs first. Seriously, read them.
