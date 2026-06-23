# RunIt Maps — Code Conventions

## Rust Style

- **Errors**: Use `ServiceError` enum with `thiserror` for domain errors. Use `anyhow::Result` at module boundaries (CLI, main). Implement `From<ServiceError> for tonic::Status`.
- **Async**: Use `tokio` with `#[async_trait]` for tonic services. Prefer `tokio::fs` for async I/O.
- **Config**: Config struct loaded via `config` crate from `config/default.toml` + env vars with `RUNIT__` prefix.
- **CLI**: `clap` derive API. Subcommands: `serve` (default), `build-tiles <region>`.
- **Logging**: `tracing` with structured fields (`info!(field = %value, ...)`).
- **Tests**: Unit tests inline with `#[cfg(test)] mod tests`. Integration tests gated behind `RUNIT_INTEGRATION_TEST` env var.

## Project Structure

```
src/
  main.rs              — CLI entrypoint, subcommand dispatch
  lib.rs               — Crate root, re-exports
  api/                 — gRPC service implementations
    routing_service.rs  — RouteRequest handler, Valhalla proxy
    admin_service.rs   — Tile reload, status queries
  routing/             — Valhalla HTTP client, response parsing
    client.rs          — HTTP client for Valhalla's /route and /health
    response_parser.rs — Maps Valhalla JSON → proto RouteResponse
    validator.rs       — RouteRequest validation
  ingestion/           — OSM + GeoJSON pipeline
    osm.rs             — OSM PBF download from Geofabrik
    geojson.rs         — GeoJSON parse → OSM XML conversion
    regional_config.rs — Region definitions (OSM URL, paths)
    tile_builder.rs    — Merge + valhalla_build_tiles orchestration
  common/              — Shared utilities
    error.rs           — ServiceError enum
    polyline.rs        — Google polyline encode/decode
    telemetry.rs       — tracing-subscriber init
  config/
    mod.rs             — AppConfig struct, env + file loading
proto/runit_maps/v1/
  routing.proto        — gRPC service + message definitions
valhalla/
  campus_cost/         — C++ custom pedestrian costing plugin
    campus_pedestrian.h / .cc — Campus-specific edge weighting
```

## GeoJSON Conventions

- Coordinates in `[longitude, latitude]` order (GeoJSON standard).
- Required properties: `name`, `campus_id`.
- Optional: `surface`, `lit`, `wheelchair`, `highway` (defaults to `"path"`).
- For stairs: `"highway": "steps"`, `"wheelchair": "no"`.
- Files stored in `data/custom_paths/{region_id}.geojson`.

## gRPC / Proto

- Services defined in `proto/runit_maps/v1/routing.proto`.
- Enum variants prefixed with type name (e.g., `COSTING_UNSPECIFIED`, `CAMPUS_PEDESTRIAN`).
- Build with `tonic-build` + `prost` in `build.rs`.
- Response fields use `optional` for nullable values.

## Git

- Commits prefixed with conventional commit type: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`.
- No force-push, no amend after push.
