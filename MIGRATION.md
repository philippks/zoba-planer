# Elm Land Migration

This document explains the migration of the Zoba Planer project from a traditional Elm application to use the Elm Land framework.

## What is Elm Land?

[Elm Land](https://elm.land/) is a production-ready framework for building Elm applications. It provides:
- File-based routing
- Hot module reloading
- Built-in development server
- Optimized production builds
- TypeScript/JavaScript interop support
- Shared state management

## Migration Overview

The project has been migrated from a single-file Elm application (`Main.elm`) to an Elm Land application structure while preserving all existing functionality.

### Key Changes

#### 1. Project Structure

**Before:**
```
├── src/
│   ├── Main.elm          # Main application with ports
│   ├── Delivery.elm      # Delivery types and logic
│   ├── Osm.elm          # OpenStreetMap integration
│   └── UI.elm           # UI components
├── index.html           # Custom HTML file
├── init.js              # JavaScript initialization
└── styles.css           # Styles
```

**After:**
```
├── src/
│   ├── App.elm          # Application logic (formerly Main.elm)
│   ├── Ports.elm        # Port definitions
│   ├── Delivery.elm     # Delivery types and logic (unchanged)
│   ├── Osm.elm          # OpenStreetMap integration (unchanged)
│   ├── UI.elm           # UI components (unchanged)
│   ├── Shared.elm       # Shared state across pages
│   ├── Shared/
│   │   ├── Model.elm    # Shared model definition
│   │   └── Msg.elm      # Shared messages
│   ├── Effect.elm       # Custom effects
│   ├── Pages/
│   │   └── Home_.elm    # Home page (renders the app)
│   └── interop.js       # JavaScript/Elm interop
├── static/
│   └── styles.css       # Static assets served by Elm Land
├── elm-land.json        # Elm Land configuration
└── .elm-land/           # Generated Elm Land files
```

#### 2. Port Integration

Ports have been extracted from `Main.elm` into a separate `Ports.elm` module:

```elm
port module Ports exposing
    ( setCachedCoordinates
    , initMap
    , clearMap
    , initRenderRouteMaps
    , addMarkers
    , markerClicked
    )
```

This allows the ports to be used across the application while following Elm Land's architecture.

#### 3. JavaScript Interop

The `init.js` file has been replaced with Elm Land's `src/interop.js`, which provides:
- Flags initialization (cached coordinates from localStorage)
- Port subscriptions setup
- Leaflet map integration

Elm Land automatically handles the JavaScript bundling and initialization.

#### 4. HTML and Asset Management

- `index.html` is no longer needed - Elm Land generates HTML from `elm-land.json` configuration
- `styles.css` moved to `static/` directory
- Leaflet CSS and JavaScript CDN links configured in `elm-land.json`

#### 5. Application Logic

The core application logic has been preserved:
- `Main.elm` renamed to `App.elm`
- Ports moved to `Ports.elm` module
- `App.elm` exports `Model`, `Msg`, `init`, `update`, `subscriptions`, and `view`
- `Pages/Home_.elm` wraps the App module and integrates it with Elm Land's page architecture

#### 6. Build System

**Before:**
```bash
elm make src/Main.elm --output=main.js
elm-live src/Main.elm --hot -- --output=main.js
```

**After:**
```bash
npm run build  # or: make build, elm-land build
npm run dev    # or: make dev, elm-land server
```

Elm Land provides:
- Built-in development server with hot reloading on port 1234
- Optimized production builds in `dist/` directory
- Automatic asset handling

## Benefits of Elm Land

1. **Better Developer Experience**: Hot module reloading, automatic routing, built-in dev server
2. **Production Ready**: Optimized builds, code splitting, asset management
3. **Type-Safe Routing**: File-based routing with type-safe route handling
4. **Easy Deployment**: Single `dist/` folder contains everything needed
5. **Future Scalability**: Easy to add new pages and features as the app grows

## Backwards Compatibility

The migration maintains full backwards compatibility:
- All existing functionality works exactly as before
- The same Elm packages are used
- The same Leaflet maps integration
- The same localStorage caching
- The same CSV parsing and delivery clustering logic

## Development Workflow

### Starting Development Server
```bash
npm run dev
```
Starts Elm Land server on http://localhost:1234

### Building for Production
```bash
npm run build
```
Creates optimized build in `dist/` directory

### File Structure
- Application logic: `src/App.elm`
- Pages: `src/Pages/*.elm`
- Shared state: `src/Shared.elm`, `src/Shared/*.elm`
- Ports: `src/Ports.elm`
- Static assets: `static/*`
- Configuration: `elm-land.json`

## Future Improvements

With Elm Land, the application can be further enhanced:
1. **Multi-page workflow**: Convert the wizard steps into separate pages with routing
   - `/` - Input CSV data
   - `/coordinates` - Fetch and verify coordinates
   - `/clustering` - Plan routes
   - `/routes` - Print routes
2. **State persistence**: Use Elm Land's shared state to preserve data across page navigation
3. **Progressive enhancement**: Add more pages for settings, history, etc.
4. **Better error handling**: Leverage Elm Land's error pages

## Notes

- The single-page architecture was preserved to minimize migration risk
- All existing modules (`Delivery.elm`, `Osm.elm`, `UI.elm`) remain unchanged
- Port interop works seamlessly with Elm Land's JavaScript integration
- The development server provides instant feedback during development
