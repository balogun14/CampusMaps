# Contributing

## PR Workflow

1. Create a feature branch from `master`
2. Make changes, keep commits small and focused
3. Run `cargo test` — all tests must pass
4. Run `cargo build` — no warnings
5. Open a PR against `master`

## Commit Style

Use conventional commits:

```
feat:     New feature
fix:      Bug fix
chore:    Tooling, dependencies, CI
docs:     Documentation only
refactor: Code change with no functional change
test:     Adding or fixing tests
```

Example: `feat: add --data-dir flag to build-tiles subcommand`

## Code Conventions

See [AGENTS.md](AGENTS.md) for:

- Rust style (errors, async, config, CLI, logging)
- Project structure
- GeoJSON conventions
- gRPC / proto conventions
- Git rules

## Running Tests

```bash
# Unit tests
cargo test

# Integration tests (requires Valhalla + osmium)
$env:RUNIT_INTEGRATION_TEST=1
cargo test
```

## Adding a New Campus

1. Create `data/custom_paths/{region_id}.geojson` with LineString features
2. Add the region ID to `config/default.toml` → `ingestion.regions`
3. Run `runit-maps build-tiles {region_id}`

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
