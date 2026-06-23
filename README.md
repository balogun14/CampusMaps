# RunIt Maps

Custom map routing microservice for campus pedestrian navigation. Ingests OpenStreetMap data, merges custom campus paths (GeoJSON), builds Valhalla routing tiles, and serves routes via gRPC.

Built for **MEDILAG** (College of Medicine, University of Lagos / LUTH) and similar campuses with unmapped pedestrian routes.

## Architecture

```
┌──────────┐    ┌──────────────┐    ┌──────────────┐    ┌───────────┐
│ GeoJSON  │───→│  osmium      │───→│  Valhalla    │───→│  gRPC     │
│ paths    │    │  merge       │    │  Tile Build  │    │  Server   │
└──────────┘    └──────────────┘    └──────────────┘    └───────────┘
                      ↑                                        │
                ┌─────┴──────┐                            ┌────┴─────┐
                │  OSM PBF   │                            │  Flutter │
                │  (Geofabrik)│                            │  Client  │
                └────────────┘                            └──────────┘
```

- **Ingestion**: Downloads OSM extracts from Geofabrik, converts custom GeoJSON paths to OSM XML, merges them with `osmium`, builds Valhalla tiles.
- **Routing**: Proxies route requests to Valhalla's HTTP API, parses responses into protobuf, handles custom `campus_pedestrian` costing.
- **Admin**: Triggers tile rebuilds, queries build status per region.

## Requirements

- Rust 1.81+
- [protoc](https://github.com/protocolbuffers/protobuf/releases) (proto compilation)
- Docker + Docker Compose (for Valhalla engine)

## Quick Start

```bash
# 1. Start Valhalla + the routing service
docker compose up -d valhalla routing-service

# 2. Build tiles for Medilag campus
docker compose --profile build run tile-builder

# 3. Test with grpcurl
grpcurl -plaintext -d '{
  "origin": {"lat": 6.5135, "lng": 3.3515},
  "destination": {"lat": 6.5165, "lng": 3.3490},
  "costing": "CAMPUS_PEDESTRIAN"
}' localhost:50051 runit_maps.v1.RoutingService/Route
```

## CLI

```text
runit-maps serve              Start the gRPC server
runit-maps build-tiles <region>  One-shot tile build
  --data-dir <path>             Data directory (default: /data)
```

## Configuration

Set via `config/default.toml` or environment variables (`RUNIT__*`):

```toml
[ingestion]
download_base_url = "https://download.geofabrik.de/africa"
regions = ["medilag-campus"]
```

## Project Structure

See [AGENTS.md](AGENTS.md) for full conventions.

## License

MIT
