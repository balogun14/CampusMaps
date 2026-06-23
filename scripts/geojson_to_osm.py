#!/usr/bin/env python3
"""
Convert a GeoJSON FeatureCollection of pedestrian paths to OSM XML format.

Usage:
    python3 geojson_to_osm.py input.geojson output.osm

The GeoJSON should contain LineString features with properties such as:
    - name: Path name
    - campus_id: Campus identifier (e.g., "mit", "harvard")
    - surface: "paved", "unpaved", "gravel", etc.
    - lit: "yes" or "no"
    - highway: "path", "footway", "steps" (defaults to "path")
    - foot: "designated", "yes", "permissive" (defaults to "designated")
"""

import json
import sys
from xml.etree.ElementTree import Element, SubElement, tostring
from xml.dom import minidom


def geojson_to_osm(geojson_path: str, osm_path: str) -> None:
    with open(geojson_path, 'r') as f:
        data = json.load(f)

    if data.get('type') != 'FeatureCollection':
        raise ValueError("Input must be a GeoJSON FeatureCollection")

    root = Element('osm')
    root.set('version', '0.6')
    root.set('generator', 'runit-maps-geojson-to-osm')

    # Use high IDs to avoid conflicts with OSM data
    node_id = 2_000_000_000
    way_id = 1_000_000_000

    for feature in data.get('features', []):
        if feature.get('geometry', {}).get('type') != 'LineString':
            continue

        coords = feature['geometry']['coordinates']
        properties = feature.get('properties', {})
        nd_refs = []

        # Create nodes
        for coord in coords:
            if len(coord) < 2:
                continue
            lon, lat = coord[0], coord[1]
            node = SubElement(root, 'node')
            node.set('id', str(node_id))
            node.set('lat', str(lat))
            node.set('lon', str(lon))
            node.set('version', '1')
            node.set('visible', 'true')
            nd_refs.append(str(node_id))
            node_id += 1

        # Create way
        way = SubElement(root, 'way')
        way.set('id', str(way_id))
        way.set('version', '1')
        way.set('visible', 'true')

        for ref in nd_refs:
            nd = SubElement(way, 'nd')
            nd.set('ref', ref)

        # Add tags from properties
        tags = {
            'highway': properties.get('highway', 'path'),
            'foot': properties.get('foot', 'designated'),
        }

        # Add optional tags if present
        for key in ['name', 'campus_id', 'surface', 'lit', 'wheelchair']:
            if key in properties:
                tags[key] = str(properties[key])

        for k, v in tags.items():
            tag = SubElement(way, 'tag')
            tag.set('k', k)
            tag.set('v', v)

        way_id += 1

    # Pretty-print XML
    rough_string = tostring(root, encoding='unicode')
    reparsed = minidom.parseString(rough_string)
    pretty = reparsed.toprettyxml(indent="  ")

    with open(osm_path, 'w') as f:
        f.write(pretty)

    print(f"Converted {len(data.get('features', []))} features")
    print(f"Output written to {osm_path}")


def main():
    if len(sys.argv) != 3:
        print("Usage: geojson_to_osm.py input.geojson output.osm", file=sys.stderr)
        sys.exit(1)

    geojson_path = sys.argv[1]
    osm_path = sys.argv[2]
    geojson_to_osm(geojson_path, osm_path)


if __name__ == '__main__':
    main()
