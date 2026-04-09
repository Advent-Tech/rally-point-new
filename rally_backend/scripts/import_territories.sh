#!/bin/bash

# Import GeoPackage territories into PostGIS
# Usage: ./import_territories.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
GEOPACKAGE_DIR="$(dirname "$BACKEND_DIR")/Geopackage"

echo "======================================"
echo "Rally Point Territory Import Script"
echo "======================================"

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker daemon is not running. Please start Docker first."
    exit 1
fi

# Change to backend directory where docker-compose.yml is located
cd "$BACKEND_DIR"
echo "Working directory: $BACKEND_DIR"

# Check if postgres container is running (try both methods)
POSTGRES_CONTAINER=$(docker ps --filter "name=rally_postgres" --format "{{.Names}}" 2>/dev/null | head -1)

if [ -z "$POSTGRES_CONTAINER" ]; then
    # Try with docker compose
    POSTGRES_CONTAINER=$(docker compose ps -q postgres 2>/dev/null)
fi

if [ -z "$POSTGRES_CONTAINER" ]; then
    echo "ERROR: PostgreSQL container is not running."
    echo "Start it with: docker compose up -d postgres"
    exit 1
fi

echo "Found PostgreSQL container: $POSTGRES_CONTAINER"

# Step 1: Apply the territories migration
echo ""
echo "Step 1: Applying territories migration..."
docker exec -i "$POSTGRES_CONTAINER" psql -U rally_user -d rally_point -f /docker-entrypoint-initdb.d/003_territories_table.sql 2>&1 || {
    echo "Note: Some errors are expected if tables already exist"
}

echo "Migration applied successfully!"

# Step 2: Check if ogr2ogr is available in the container
echo ""
echo "Step 2: Checking for ogr2ogr (GDAL)..."

# First check if GDAL is already installed
if docker exec -i "$POSTGRES_CONTAINER" which ogr2ogr > /dev/null 2>&1; then
    echo "ogr2ogr is available"
else
    echo "Installing GDAL in postgres container..."
    docker exec -i "$POSTGRES_CONTAINER" apk add --no-cache gdal gdal-tools
fi

# Step 3: Import each GeoPackage file
echo ""
echo "Step 3: Importing GeoPackage files..."

# List of GeoPackage files
GPKG_FILES=(
    "Union_Atlantic Union.gpkg"
    "Union_Columbia Union.gpkg"
    "Union_Lake Union.gpkg"
    "Union_Mid-America Union.gpkg"
    "Union_North Pacific Union.gpkg"
    "Union_Pacific Union.gpkg"
    "Union_Southern Union.gpkg"
    "Union_Southwestern Union.gpkg"
)

TOTAL_IMPORTED=0

for gpkg in "${GPKG_FILES[@]}"; do
    if [ -f "$GEOPACKAGE_DIR/$gpkg" ]; then
        echo ""
        echo "Importing: $gpkg"

        # Get the table name (same as file name without extension)
        TABLE_NAME="${gpkg%.gpkg}"

        # Import using ogr2ogr
        docker exec -i "$POSTGRES_CONTAINER" ogr2ogr \
            -f "PostgreSQL" \
            PG:"host=localhost dbname=rally_point user=rally_user password=rally_password" \
            "/geopackage/$gpkg" \
            -nln territories \
            -append \
            -t_srs EPSG:4326 \
            -lco GEOMETRY_NAME=geom \
            -lco FID=fid \
            --config OGR_TRUNCATE NO \
            -sql "SELECT
                fid,
                SOLID as solid,
                Entity as entity_name,
                EID as entity_id,
                GID as group_id,
                Address as address,
                \"Street Add\" as street_address,
                City as city,
                County as county,
                State as state,
                Zipcode as zipcode,
                CAST(REPLACE(Population, ',', '') AS INTEGER) as population,
                CAST(REPLACE(Housing, ',', '') AS INTEGER) as housing_units,
                \"Union\" as union_name,
                Conference as conference,
                GEOID as geoid,
                ZID as zid,
                Label as label,
                \"Order\" as territory_order,
                geom
            FROM \"$TABLE_NAME\"" 2>&1 || echo "Warning: Some errors during import of $gpkg"

        # Count imported records
        COUNT=$(docker exec -i "$POSTGRES_CONTAINER" psql -U rally_user -d rally_point -t -c "SELECT COUNT(*) FROM territories WHERE source_file = '$gpkg'" 2>/dev/null | tr -d ' ')
        echo "Imported records from $gpkg: $COUNT"
        TOTAL_IMPORTED=$((TOTAL_IMPORTED + COUNT))
    else
        echo "WARNING: File not found: $GEOPACKAGE_DIR/$gpkg"
    fi
done

# Step 4: Post-import tasks
echo ""
echo "Step 4: Running post-import tasks..."

# Update source_file for records that don't have it
docker exec -i "$POSTGRES_CONTAINER" psql -U rally_user -d rally_point -c "
    UPDATE territories
    SET source_file = COALESCE(source_file, 'imported')
    WHERE source_file IS NULL;
"

# Generate simplified geometries
echo "Generating simplified geometries..."
docker exec -i "$POSTGRES_CONTAINER" psql -U rally_user -d rally_point -c "
    UPDATE territories
    SET geom_simplified = ST_Simplify(geom, 0.001)
    WHERE geom_simplified IS NULL;
"

# Refresh the church_locations materialized view
echo "Refreshing church locations view..."
docker exec -i "$POSTGRES_CONTAINER" psql -U rally_user -d rally_point -c "
    REFRESH MATERIALIZED VIEW church_locations;
"

# Step 5: Show summary
echo ""
echo "======================================"
echo "Import Complete!"
echo "======================================"

docker exec -i "$POSTGRES_CONTAINER" psql -U rally_user -d rally_point -c "
    SELECT
        union_name,
        COUNT(*) as territories,
        COUNT(DISTINCT entity_id) as churches,
        COUNT(DISTINCT conference) as conferences
    FROM territories
    WHERE union_name IS NOT NULL
    GROUP BY union_name
    ORDER BY union_name;
"

echo ""
TOTAL=$(docker exec -i "$POSTGRES_CONTAINER" psql -U rally_user -d rally_point -t -c "SELECT COUNT(*) FROM territories" | tr -d ' ')
echo "Total territories imported: $TOTAL"

echo ""
echo "You can now rebuild the territory-service:"
echo "  docker compose build territory-service"
echo "  docker compose up -d territory-service"
