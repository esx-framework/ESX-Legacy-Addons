# ESX Garages - Modern TypeScript UI for FiveM

![TypeScript](https://img.shields.io/badge/TypeScript-5.8-blue)
![React](https://img.shields.io/badge/React-19.1-61dafb)
![Vite](https://img.shields.io/badge/Vite-7.1-646cff)
![License](https://img.shields.io/badge/License-MIT-green)

A modern, type-safe garage management UI for ESX Framework in FiveM. Built with React 19, TypeScript 5.8, and optimized for performance in the CEF/NUI environment.

## Features

- **Modern UI Design** - Clean, dark theme with customizable colors
- **High Performance** - Virtual scrolling support for large vehicle lists
- **Responsive Scaling** - Automatic scaling for different resolutions (720p to 4K)
- **Search & Filter** - Real-time vehicle search with multiple filter options
- **Favorites System** - Mark vehicles as favorites for quick access
- **Custom Names** - Rename vehicles with custom display names
- **Vehicle Management** - Store, retrieve, and manage vehicles
- **Impound System** - Handle impounded vehicles with configurable fees
- **Type-Safe** - Full TypeScript support with strict mode enabled
- **FiveM Optimized** - Built specifically for NUI/CEF environment

## Technology Stack

### Core
- **React 19.1** - Latest React with concurrent features
- **TypeScript 5.8** - Type-safe development with strict mode
- **Vite 7.1** - Lightning fast build tool with Hot Module Replacement

### UI & Styling
- **Styled Components 6.1** - CSS-in-JS with TypeScript support
- **Framer Motion 12.x** - Smooth, performant animations
- **React Icons 5.x** - Icon library

### State Management
- **Zustand 5.0** - Lightweight state management
- **Immer 10.x** - Immutable state updates
- **React Query 5.x** - Server state management

### Validation & Types
- **Zod 4.x** - Runtime type validation
- **TypeScript** - Compile-time type checking

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/esx_garages.git

# Navigate to the UI directory
cd esx_garages/esx_garages

# Install dependencies
npm install

# Start development server
npm run dev
```

## Available Scripts

```bash
npm run dev          # Start development server on port 3000
npm run build        # Build for production (outputs to /build)
npm run type-check   # Run TypeScript type checking
npm run lint         # Lint code with ESLint
npm run format       # Format code with Prettier
npm run test         # Run tests with Vitest
npm run preview      # Preview production build locally
```

## Project Structure

```
src/
├── components/        # React components
│   ├── common/       # Reusable UI components
│   ├── garage/       # Garage-specific components
│   └── vehicle/      # Vehicle-related components
├── hooks/            # Custom React hooks
├── providers/        # React Context providers
├── services/         # API/NUI services (future use)
├── store/            # Zustand state management
├── types/            # TypeScript type definitions
├── utils/            # Utility functions
├── styles/           # Theme and global styles
├── constants/        # App constants and mock data
└── schemas/          # Zod validation schemas
```

## FiveM Integration

### Opening the Garage UI

```lua
SendNUIMessage({
    type = 'openGarage',
    payload = {
        garage = {
            id = 'garage_central',
            name = 'Central Garage',
            label = 'Los Santos Central Garage',
            type = 'public'
        },
        vehicles = {
            {
                id = '1',
                plate = 'ABC123',
                model = 'sultan',
                name = 'Sultan RS',
                type = 'car',
                stored = true,
                impounded = false,
                mileage = 12500,
                fuel = 85,
                engine = 95,
                body = 100
            }
        }
    }
})

SetNuiFocus(true, true)
```

### Registering NUI Callbacks

```lua
RegisterNUICallback('garage:retrieveVehicle', function(data, cb)
    local vehicleId = data.vehicleId

    -- Implement your vehicle spawn logic here

    cb({ success = true })
end)

RegisterNUICallback('garage:storeVehicle', function(data, cb)
    local vehicleId = data.vehicleId
    local garageId = data.garageId

    -- Implement your vehicle storage logic here

    cb({ success = true })
end)

RegisterNUICallback('garage:closeUI', function(data, cb)
    SetNuiFocus(false, false)
    cb({ success = true })
end)
```

For complete NUI integration documentation, see:
- `NUI_EVENTS.md` - Complete event reference
- `LUA_INTEGRATION.md` - Detailed integration guide
- `BACKEND_TODO.md` - Quick start for backend developers

## Customization

### Theme Configuration

Edit `src/styles/theme.ts` to customize the UI theme:

```typescript
export const theme = {
  colors: {
    primary: '#FB9B04',     // Primary accent color
    secondary: '#FF8080',   // Secondary accent (impound)
    background: '#161616',  // Dark background
    surface: '#1E1E1E',     // Component background
    // ... more colors
  },
  fonts: {
    primary: "'Inter', sans-serif",
    mono: "'JetBrains Mono', monospace"
  }
}
```

### Locale Support

The UI includes built-in support for multiple languages:
- German (de)
- English (en)

Additional languages can be added in `src/locales/`.

## Type Safety

The project uses TypeScript with strict mode enabled. All data flows between the UI and game client are fully typed:

```typescript
interface Vehicle {
  id: string;
  plate: string;
  model: string;
  name: string;
  type: VehicleType;
  stored: boolean;
  garage?: string;
  impounded: boolean;
  impoundFee?: number;
  mileage: number;
  fuel?: number;
  engine?: number;
  body?: number;
  isFavorite?: boolean;
  customName?: string;
  lastUsed?: number;
}

type VehicleType = 'car' | 'motorcycle' | 'boat' | 'aircraft' | 'bicycle' | 'truck' | 'emergency';
```

Runtime validation is performed using Zod schemas to ensure data integrity.

## Development

### Mock Data

In development mode, mock data is automatically loaded after 1 second to facilitate UI development without a FiveM client.

### Debug Mode

Debug mode is automatically enabled in development:

```typescript
// Enables console logging of NUI events
localStorage.setItem('debug', 'true');
```

### Building for Production

```bash
# Type check and build
npm run build

# Output will be in /build directory
# Include this directory in your FiveM resource
```

## Code Quality

- **ESLint** - Code linting with TypeScript rules
- **Prettier** - Automatic code formatting
- **Husky** - Git hooks for pre-commit checks
- **TypeScript Strict Mode** - Maximum type safety
- **Zod Validation** - Runtime type validation

## Architecture

The application follows a modern React architecture:

- **Provider Pattern** - Context-based state sharing
- **Custom Hooks** - Reusable logic abstraction
- **Zustand Store** - Centralized state management
- **Styled Components** - Component-scoped styling
- **Type-First** - TypeScript-driven development

## Performance Considerations

- React.memo for component optimization
- Virtual scrolling support for large lists
- Debounced search input
- Optimized re-renders with proper dependencies
- Efficient state updates with Immer

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Credits

- Built for ESX Framework
- Designed for modern FiveM development
- Inspired by real-world garage management systems

## Support

For support, please open an issue on GitHub.
