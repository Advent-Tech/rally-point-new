#!/usr/bin/env python3
"""
Import GeoPackage territories into PostGIS

Requirements:
    pip install psycopg2-binary

Usage:
    python import_territories.py
"""

import os
import sys
import sqlite3
import struct
import json
from pathlib import Path

try:
    import psycopg2
    from psycopg2.extras import execute_values
except ImportError:
    print("ERROR: psycopg2 is required. Install with: pip install psycopg2-binary")
    sys.exit(1)


# Database configuration
DB_CONFIG = {
    'host': os.environ.get('DB_HOST', 'localhost'),
    'port': int(os.environ.get('DB_PORT', 5432)),
    'dbname': os.environ.get('DB_NAME', 'rally_point'),
    'user': os.environ.get('DB_USER', 'rally_user'),
    'password': os.environ.get('DB_PASSWORD', 'rally_password'),
}

# Path to GeoPackage files
SCRIPT_DIR = Path(__file__).parent
GEOPACKAGE_DIR = SCRIPT_DIR.parent.parent / 'Geopackage'


def extract_wkb_from_gpkg(gpkg_blob):
    """Extract WKB from GeoPackage geometry binary format"""
    if gpkg_blob is None or len(gpkg_blob) < 8:
        return None

    # Check magic number "GP" (0x47, 0x50)
    if gpkg_blob[0:2] != b'GP':
        # Might already be WKB
        return gpkg_blob

    # Flags byte determines envelope size
    flags = gpkg_blob[3]
    envelope_type = (flags >> 1) & 0x07

    # Calculate envelope size based on type
    envelope_sizes = {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}
    envelope_size = envelope_sizes.get(envelope_type, 0)

    # WKB starts after header (8 bytes) + envelope
    wkb_start = 8 + envelope_size
    if wkb_start >= len(gpkg_blob):
        return None

    return gpkg_blob[wkb_start:]


def parse_int(value):
    """Parse integer from string, handling commas and decimals"""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return int(value)
    try:
        return int(float(str(value).replace(',', '')))
    except (ValueError, TypeError):
        return None


def import_geopackage(gpkg_path, pg_conn):
    """Import a single GeoPackage file into PostGIS"""
    filename = gpkg_path.name
    print(f"\nImporting: {filename}")

    # Open GeoPackage (SQLite)
    sqlite_conn = sqlite3.connect(str(gpkg_path))
    sqlite_conn.row_factory = sqlite3.Row
    cursor = sqlite_conn.cursor()

    # Get table name from gpkg_contents
    cursor.execute("SELECT table_name FROM gpkg_contents WHERE data_type = 'features' LIMIT 1")
    row = cursor.fetchone()
    if not row:
        print(f"  ERROR: No features table found in {filename}")
        return 0

    table_name = row['table_name']
    print(f"  Table: {table_name}")

    # Count records
    cursor.execute(f'SELECT COUNT(*) as cnt FROM "{table_name}"')
    total_count = cursor.fetchone()['cnt']
    print(f"  Total records: {total_count}")

    # Query all features
    query = f'''
        SELECT
            fid,
            SOLID,
            Entity,
            EID,
            GID,
            Address,
            "Street Add" as StreetAdd,
            City,
            County,
            State,
            Zipcode,
            Population,
            Housing,
            "Union" as UnionName,
            Conference,
            GEOID,
            ZID,
            Label,
            "Order" as TerritoryOrder,
            geom
        FROM "{table_name}"
    '''

    cursor.execute(query)

    # Prepare PostgreSQL cursor
    pg_cursor = pg_conn.cursor()

    # Insert in batches
    batch_size = 500
    imported = 0
    failed = 0
    batch = []

    for row in cursor:
        try:
            # Extract WKB from GeoPackage geometry
            wkb = extract_wkb_from_gpkg(row['geom'])
            if wkb is None:
                failed += 1
                continue

            record = (
                row['fid'],
                row['SOLID'],
                row['Entity'],
                row['EID'],
                row['GID'],
                row['Address'],
                row['StreetAdd'],
                row['City'],
                row['County'],
                row['State'],
                row['Zipcode'],
                parse_int(row['Population']),
                parse_int(row['Housing']),
                row['UnionName'],
                row['Conference'],
                row['GEOID'],
                row['ZID'],
                row['Label'],
                row['TerritoryOrder'],
                wkb.hex(),  # Convert to hex for ST_GeomFromWKB
                filename,
            )
            batch.append(record)

            if len(batch) >= batch_size:
                batch_inserted = insert_batch(pg_cursor, pg_conn, batch)
                pg_conn.commit()
                imported += batch_inserted
                failed += len(batch) - batch_inserted
                print(f"  Progress: {imported}/{total_count} ({100*imported//total_count}%)", end='\r')
                batch = []

        except Exception as e:
            failed += 1
            if failed < 5:
                print(f"  Error on fid {row['fid']}: {e}")

    # Insert remaining records
    if batch:
        batch_inserted = insert_batch(pg_cursor, pg_conn, batch)
        pg_conn.commit()
        imported += batch_inserted
        failed += len(batch) - batch_inserted

    print(f"  Completed: {imported} imported, {failed} failed")

    sqlite_conn.close()
    return imported


def insert_batch(cursor, conn, batch):
    """Insert a batch of records into PostgreSQL"""
    query = '''
        INSERT INTO territories (
            fid, solid, entity_name, entity_id, group_id,
            address, street_address, city, county, state, zipcode,
            population, housing_units, union_name, conference,
            geoid, zid, label, territory_order, geom, source_file
        ) VALUES (
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s,
            %s, %s, %s, %s, ST_GeomFromWKB(decode(%s, 'hex'), 4326), %s
        )
        ON CONFLICT (fid) DO UPDATE SET
            entity_name = EXCLUDED.entity_name,
            address = EXCLUDED.address,
            city = EXCLUDED.city,
            state = EXCLUDED.state,
            population = EXCLUDED.population,
            housing_units = EXCLUDED.housing_units,
            geom = EXCLUDED.geom,
            source_file = EXCLUDED.source_file,
            updated_at = NOW()
    '''

    inserted = 0
    for record in batch:
        try:
            cursor.execute(query, record)
            inserted += 1
        except Exception as e:
            conn.rollback()  # Reset transaction on error
            # Skip this record and continue
    return inserted


def post_import_tasks(conn):
    """Run post-import cleanup and optimization tasks"""
    cursor = conn.cursor()

    print("\nRunning post-import tasks...")

    try:
        # Generate simplified geometries
        print("  Generating simplified geometries...")
        cursor.execute('''
            UPDATE territories
            SET geom_simplified = ST_Simplify(geom, 0.001)
            WHERE geom_simplified IS NULL
        ''')
        conn.commit()
    except Exception as e:
        print(f"  Warning: Failed to generate simplified geometries: {e}")
        conn.rollback()

    try:
        # Refresh church locations view
        print("  Refreshing church locations view...")
        cursor.execute('REFRESH MATERIALIZED VIEW church_locations')
        conn.commit()
    except Exception as e:
        print(f"  Warning: Failed to refresh church_locations view: {e}")
        conn.rollback()

    print("  Done!")


def print_summary(conn):
    """Print import summary"""
    cursor = conn.cursor()

    print("\n" + "=" * 50)
    print("IMPORT SUMMARY")
    print("=" * 50)

    cursor.execute('''
        SELECT
            union_name,
            COUNT(*) as territories,
            COUNT(DISTINCT entity_id) as churches,
            COUNT(DISTINCT conference) as conferences,
            SUM(COALESCE(population, 0)) as total_population
        FROM territories
        WHERE union_name IS NOT NULL
        GROUP BY union_name
        ORDER BY union_name
    ''')

    print(f"\n{'Union':<30} {'Territories':>12} {'Churches':>10} {'Conferences':>12} {'Population':>15}")
    print("-" * 80)

    total_territories = 0
    total_churches = 0
    for row in cursor.fetchall():
        union, territories, churches, conferences, population = row
        print(f"{union:<30} {territories:>12} {churches:>10} {conferences:>12} {population:>15,}")
        total_territories += territories
        total_churches += churches

    print("-" * 80)
    print(f"{'TOTAL':<30} {total_territories:>12} {total_churches:>10}")

    cursor.execute('SELECT COUNT(*) FROM territories')
    total = cursor.fetchone()[0]
    print(f"\nTotal territories in database: {total:,}")


def main():
    print("=" * 50)
    print("Rally Point Territory Import")
    print("=" * 50)

    # Check GeoPackage directory
    if not GEOPACKAGE_DIR.exists():
        print(f"ERROR: GeoPackage directory not found: {GEOPACKAGE_DIR}")
        sys.exit(1)

    # List GeoPackage files
    gpkg_files = sorted(GEOPACKAGE_DIR.glob("*.gpkg"))
    if not gpkg_files:
        print(f"ERROR: No GeoPackage files found in {GEOPACKAGE_DIR}")
        sys.exit(1)

    print(f"\nFound {len(gpkg_files)} GeoPackage files")
    for f in gpkg_files:
        print(f"  - {f.name}")

    # Connect to PostgreSQL
    print(f"\nConnecting to PostgreSQL at {DB_CONFIG['host']}:{DB_CONFIG['port']}...")
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        print("Connected!")
    except Exception as e:
        print(f"ERROR: Failed to connect to PostgreSQL: {e}")
        sys.exit(1)

    # Import each file
    total_imported = 0
    for gpkg_file in gpkg_files:
        try:
            imported = import_geopackage(gpkg_file, conn)
            total_imported += imported
        except Exception as e:
            print(f"ERROR importing {gpkg_file.name}: {e}")

    # Run post-import tasks
    post_import_tasks(conn)

    # Print summary
    print_summary(conn)

    conn.close()
    print("\nImport complete!")


if __name__ == '__main__':
    main()
