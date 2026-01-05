import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Platform,
  TouchableOpacity,
  ActivityIndicator,
  TextInput,
  ScrollView,
  Modal,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { COLORS, SPACING, TYPOGRAPHY, RADIUS } from '../constants/Colors';
import geoTerritoryService, {
  GeoJSONFeatureCollection,
  GeoTerritory,
  ChurchLocation,
  BoundsQuery,
} from '../services/GeoTerritoryService';

interface GeoTerritoryMapProps {
  height?: number | string;
  initialRegion?: {
    latitude: number;
    longitude: number;
    latitudeDelta: number;
    longitudeDelta: number;
  };
  onTerritorySelect?: (territory: GeoTerritory) => void;
  onChurchSelect?: (church: ChurchLocation) => void;
  showSearch?: boolean;
  showStats?: boolean;
  selectedTerritoryId?: string;
}

interface SelectedFeature {
  type: 'territory' | 'church';
  data: GeoTerritory | ChurchLocation;
}

const GeoTerritoryMap: React.FC<GeoTerritoryMapProps> = ({
  height = 500,
  initialRegion = {
    latitude: 39.8283,
    longitude: -98.5795,
    latitudeDelta: 30,
    longitudeDelta: 30,
  },
  onTerritorySelect,
  onChurchSelect,
  showSearch = true,
  showStats = true,
  selectedTerritoryId,
}) => {
  const [isLoading, setIsLoading] = useState(true);
  const [territories, setTerritories] = useState<GeoJSONFeatureCollection | null>(null);
  const [churches, setChurches] = useState<ChurchLocation[]>([]);
  const [selectedFeature, setSelectedFeature] = useState<SelectedFeature | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<any[]>([]);
  const [showSearchResults, setShowSearchResults] = useState(false);
  const [mapReady, setMapReady] = useState(false);
  const [currentBounds, setCurrentBounds] = useState<BoundsQuery | null>(null);
  const [stats, setStats] = useState<{ territories: number; churches: number }>({ territories: 0, churches: 0 });

  const mapRef = useRef<any>(null);
  const debounceRef = useRef<NodeJS.Timeout | null>(null);

  // Load initial data
  useEffect(() => {
    loadStats();
  }, []);

  // Load territories when bounds change
  useEffect(() => {
    if (currentBounds && mapReady) {
      loadTerritoriesInBounds(currentBounds);
    }
  }, [currentBounds, mapReady]);

  const loadStats = async () => {
    try {
      const unionStats = await geoTerritoryService.getUnionStats();
      const totalTerritories = unionStats.unions.reduce((sum, u) => sum + u.territory_count, 0);
      const totalChurches = unionStats.unions.reduce((sum, u) => sum + u.church_count, 0);
      setStats({ territories: totalTerritories, churches: totalChurches });
    } catch (error) {
      console.error('Error loading stats:', error);
    }
  };

  const loadTerritoriesInBounds = async (bounds: BoundsQuery) => {
    try {
      setIsLoading(true);

      // Determine zoom level from bounds for simplified geometry
      const latDelta = bounds.maxLat - bounds.minLat;
      const zoom = Math.round(Math.log2(180 / latDelta));

      const [geoJson, churchData] = await Promise.all([
        geoTerritoryService.getTerritoriesInBounds({ ...bounds, zoom, limit: 2000 }),
        geoTerritoryService.getChurchLocations(bounds),
      ]);

      setTerritories(geoJson);
      setChurches(churchData.churches);

      console.log(`Loaded ${geoJson.features.length} territories and ${churchData.churches.length} churches`);
    } catch (error) {
      console.error('Error loading territories:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSearch = useCallback(async (query: string) => {
    if (!query.trim()) {
      setSearchResults([]);
      setShowSearchResults(false);
      return;
    }

    try {
      const results = await geoTerritoryService.searchTerritories({
        query,
        limit: 20,
      });
      setSearchResults(results.territories);
      setShowSearchResults(true);
    } catch (error) {
      console.error('Search error:', error);
    }
  }, []);

  const debouncedSearch = useCallback((query: string) => {
    setSearchQuery(query);
    if (debounceRef.current) {
      clearTimeout(debounceRef.current);
    }
    debounceRef.current = setTimeout(() => handleSearch(query), 300);
  }, [handleSearch]);

  const handleSearchResultSelect = async (result: any) => {
    setShowSearchResults(false);
    setSearchQuery(result.entity_name || '');

    try {
      const territory = await geoTerritoryService.getTerritoryById(result.id);
      setSelectedFeature({ type: 'territory', data: territory });
      onTerritorySelect?.(territory);

      // Center map on territory
      if (mapRef.current && Platform.OS === 'web') {
        mapRef.current.contentWindow?.postMessage({
          type: 'centerOnTerritory',
          territoryId: result.id,
        }, '*');
      }
    } catch (error) {
      console.error('Error fetching territory details:', error);
    }
  };

  const handleMapReady = () => {
    setMapReady(true);
    // Set initial bounds
    const bounds = geoTerritoryService.regionToBounds(initialRegion);
    setCurrentBounds(bounds);
  };

  const handleBoundsChange = (bounds: BoundsQuery) => {
    setCurrentBounds(bounds);
  };

  const handleFeatureClick = async (featureId: string, featureType: 'territory' | 'church') => {
    try {
      if (featureType === 'territory') {
        const territory = await geoTerritoryService.getTerritoryById(featureId);
        setSelectedFeature({ type: 'territory', data: territory });
        onTerritorySelect?.(territory);
      } else {
        const church = await geoTerritoryService.getChurch(featureId);
        setSelectedFeature({ type: 'church', data: church });
        onChurchSelect?.(church);
      }
    } catch (error) {
      console.error('Error fetching feature details:', error);
    }
  };

  const getMapHTML = () => `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Territory Map</title>
        <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            html, body { height: 100%; width: 100%; }
            #map { height: 100%; width: 100%; }
            .territory-popup {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                min-width: 200px;
            }
            .territory-popup h3 {
                font-size: 14px;
                font-weight: 600;
                color: #1e293b;
                margin-bottom: 8px;
            }
            .territory-popup p {
                font-size: 12px;
                color: #64748b;
                margin: 4px 0;
            }
            .territory-popup .stat {
                font-weight: 500;
                color: #3b82f6;
            }
            .church-marker {
                background: #3b82f6;
                border: 2px solid white;
                border-radius: 50%;
                width: 12px;
                height: 12px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.3);
            }
        </style>
    </head>
    <body>
        <div id="map"></div>
        <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
        <script>
            let map = null;
            let territoryLayer = null;
            let churchLayer = null;
            let selectedTerritoryId = null;

            function initMap() {
                map = L.map('map', {
                    zoomControl: true,
                    attributionControl: false
                }).setView([${initialRegion.latitude}, ${initialRegion.longitude}], 5);

                L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
                    maxZoom: 19,
                    subdomains: 'abcd'
                }).addTo(map);

                territoryLayer = L.geoJSON(null, {
                    style: function(feature) {
                        const isSelected = feature.properties.id === selectedTerritoryId;
                        return {
                            fillColor: isSelected ? '#f59e0b' : '#3b82f6',
                            fillOpacity: isSelected ? 0.5 : 0.2,
                            color: isSelected ? '#d97706' : '#2563eb',
                            weight: isSelected ? 3 : 1,
                        };
                    },
                    onEachFeature: function(feature, layer) {
                        const props = feature.properties;
                        const popup = \`
                            <div class="territory-popup">
                                <h3>\${props.entity_name || 'Unknown'}</h3>
                                <p>\${props.city || ''}\${props.city && props.state ? ', ' : ''}\${props.state || ''}</p>
                                <p>Union: <span class="stat">\${props.union_name || 'N/A'}</span></p>
                                <p>Conference: <span class="stat">\${props.conference || 'N/A'}</span></p>
                                <p>Population: <span class="stat">\${(props.population || 0).toLocaleString()}</span></p>
                            </div>
                        \`;
                        layer.bindPopup(popup);

                        layer.on('click', function() {
                            window.parent.postMessage({
                                type: 'territoryClick',
                                id: props.id || feature.id,
                            }, '*');
                        });
                    }
                }).addTo(map);

                churchLayer = L.layerGroup().addTo(map);

                // Notify parent that map is ready
                window.parent.postMessage({ type: 'mapReady' }, '*');

                // Send bounds on move
                map.on('moveend', function() {
                    const bounds = map.getBounds();
                    window.parent.postMessage({
                        type: 'boundsChange',
                        bounds: {
                            minLng: bounds.getWest(),
                            minLat: bounds.getSouth(),
                            maxLng: bounds.getEast(),
                            maxLat: bounds.getNorth(),
                        }
                    }, '*');
                });

                // Initial bounds
                const bounds = map.getBounds();
                window.parent.postMessage({
                    type: 'boundsChange',
                    bounds: {
                        minLng: bounds.getWest(),
                        minLat: bounds.getSouth(),
                        maxLng: bounds.getEast(),
                        maxLat: bounds.getNorth(),
                    }
                }, '*');
            }

            function updateTerritories(geojson) {
                if (territoryLayer) {
                    territoryLayer.clearLayers();
                    if (geojson && geojson.features) {
                        territoryLayer.addData(geojson);
                    }
                }
            }

            function updateChurches(churches) {
                if (churchLayer) {
                    churchLayer.clearLayers();
                    churches.forEach(function(church) {
                        const marker = L.circleMarker([church.latitude, church.longitude], {
                            radius: 6,
                            fillColor: '#3b82f6',
                            color: '#ffffff',
                            weight: 2,
                            fillOpacity: 0.9,
                        });

                        const popup = \`
                            <div class="territory-popup">
                                <h3>\${church.entity_name}</h3>
                                <p>\${church.city || ''}\${church.city && church.state ? ', ' : ''}\${church.state || ''}</p>
                                <p>Territories: <span class="stat">\${church.territory_count}</span></p>
                                <p>Population: <span class="stat">\${(church.total_population || 0).toLocaleString()}</span></p>
                            </div>
                        \`;
                        marker.bindPopup(popup);

                        marker.on('click', function() {
                            window.parent.postMessage({
                                type: 'churchClick',
                                id: church.entity_id,
                            }, '*');
                        });

                        churchLayer.addLayer(marker);
                    });
                }
            }

            function setSelectedTerritory(id) {
                selectedTerritoryId = id;
                if (territoryLayer) {
                    territoryLayer.setStyle(function(feature) {
                        const isSelected = feature.properties.id === id;
                        return {
                            fillColor: isSelected ? '#f59e0b' : '#3b82f6',
                            fillOpacity: isSelected ? 0.5 : 0.2,
                            color: isSelected ? '#d97706' : '#2563eb',
                            weight: isSelected ? 3 : 1,
                        };
                    });
                }
            }

            function centerOnTerritory(id) {
                if (territoryLayer) {
                    territoryLayer.eachLayer(function(layer) {
                        if (layer.feature && layer.feature.properties.id === id) {
                            map.fitBounds(layer.getBounds(), { padding: [50, 50] });
                        }
                    });
                }
            }

            // Listen for messages from React Native
            window.addEventListener('message', function(event) {
                const data = event.data;

                if (data.type === 'updateTerritories') {
                    updateTerritories(data.geojson);
                } else if (data.type === 'updateChurches') {
                    updateChurches(data.churches);
                } else if (data.type === 'setSelectedTerritory') {
                    setSelectedTerritory(data.id);
                } else if (data.type === 'centerOnTerritory') {
                    centerOnTerritory(data.territoryId);
                }
            });

            document.addEventListener('DOMContentLoaded', initMap);
        </script>
    </body>
    </html>
  `;

  // Handle messages from iframe
  useEffect(() => {
    if (Platform.OS !== 'web') return;

    const handleMessage = (event: MessageEvent) => {
      const data = event.data;

      if (data.type === 'mapReady') {
        handleMapReady();
      } else if (data.type === 'boundsChange') {
        handleBoundsChange(data.bounds);
      } else if (data.type === 'territoryClick') {
        handleFeatureClick(data.id, 'territory');
      } else if (data.type === 'churchClick') {
        handleFeatureClick(data.id, 'church');
      }
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, []);

  // Update map when territories change
  useEffect(() => {
    if (mapRef.current && territories && Platform.OS === 'web') {
      mapRef.current.contentWindow?.postMessage({
        type: 'updateTerritories',
        geojson: territories,
      }, '*');
    }
  }, [territories]);

  // Update map when churches change
  useEffect(() => {
    if (mapRef.current && churches.length > 0 && Platform.OS === 'web') {
      mapRef.current.contentWindow?.postMessage({
        type: 'updateChurches',
        churches,
      }, '*');
    }
  }, [churches]);

  // Update selected territory
  useEffect(() => {
    if (mapRef.current && selectedTerritoryId && Platform.OS === 'web') {
      mapRef.current.contentWindow?.postMessage({
        type: 'setSelectedTerritory',
        id: selectedTerritoryId,
      }, '*');
    }
  }, [selectedTerritoryId]);

  const renderSelectedFeatureInfo = () => {
    if (!selectedFeature) return null;

    const isTerritory = selectedFeature.type === 'territory';
    const data = selectedFeature.data as any;

    return (
      <View style={styles.infoPanel}>
        <View style={styles.infoPanelHeader}>
          <Text style={styles.infoPanelTitle}>{data.entity_name}</Text>
          <TouchableOpacity onPress={() => setSelectedFeature(null)}>
            <MaterialIcons name="close" size={24} color={COLORS.text.secondary} />
          </TouchableOpacity>
        </View>

        <View style={styles.infoPanelBody}>
          {data.city && data.state && (
            <Text style={styles.infoPanelLocation}>
              <MaterialIcons name="place" size={14} color={COLORS.primary} />
              {' '}{data.city}, {data.state}
            </Text>
          )}

          <View style={styles.infoPanelStats}>
            {isTerritory && (
              <>
                <View style={styles.statItem}>
                  <Text style={styles.statValue}>{(data.population || 0).toLocaleString()}</Text>
                  <Text style={styles.statLabel}>Population</Text>
                </View>
                <View style={styles.statItem}>
                  <Text style={styles.statValue}>{(data.housing_units || 0).toLocaleString()}</Text>
                  <Text style={styles.statLabel}>Housing Units</Text>
                </View>
              </>
            )}
            {!isTerritory && (
              <>
                <View style={styles.statItem}>
                  <Text style={styles.statValue}>{data.territory_count}</Text>
                  <Text style={styles.statLabel}>Territories</Text>
                </View>
                <View style={styles.statItem}>
                  <Text style={styles.statValue}>{(data.total_population || 0).toLocaleString()}</Text>
                  <Text style={styles.statLabel}>Total Pop.</Text>
                </View>
              </>
            )}
          </View>

          <View style={styles.infoPanelMeta}>
            <Text style={styles.metaText}>
              <Text style={styles.metaLabel}>Union: </Text>
              {data.union_name || 'N/A'}
            </Text>
            <Text style={styles.metaText}>
              <Text style={styles.metaLabel}>Conference: </Text>
              {data.conference || 'N/A'}
            </Text>
            {isTerritory && data.solid && (
              <Text style={styles.metaText}>
                <Text style={styles.metaLabel}>SOLID: </Text>
                {data.solid}
              </Text>
            )}
          </View>
        </View>
      </View>
    );
  };

  return (
    <View style={[styles.container, { height: typeof height === 'number' ? height : undefined, flex: height === '100%' ? 1 : undefined }]}>
      {/* Search Bar */}
      {showSearch && (
        <View style={styles.searchContainer}>
          <View style={styles.searchInputContainer}>
            <MaterialIcons name="search" size={20} color={COLORS.text.secondary} />
            <TextInput
              style={styles.searchInput}
              placeholder="Search churches, cities, or territories..."
              value={searchQuery}
              onChangeText={debouncedSearch}
              placeholderTextColor={COLORS.text.secondary}
            />
            {searchQuery.length > 0 && (
              <TouchableOpacity onPress={() => {
                setSearchQuery('');
                setSearchResults([]);
                setShowSearchResults(false);
              }}>
                <MaterialIcons name="close" size={20} color={COLORS.text.secondary} />
              </TouchableOpacity>
            )}
          </View>

          {/* Search Results Dropdown */}
          {showSearchResults && searchResults.length > 0 && (
            <View style={styles.searchResults}>
              <ScrollView style={{ maxHeight: 200 }}>
                {searchResults.map((result, index) => (
                  <TouchableOpacity
                    key={result.id || index}
                    style={styles.searchResultItem}
                    onPress={() => handleSearchResultSelect(result)}
                  >
                    <MaterialIcons name="place" size={16} color={COLORS.primary} />
                    <View style={styles.searchResultText}>
                      <Text style={styles.searchResultTitle}>{result.entity_name}</Text>
                      <Text style={styles.searchResultSubtitle}>
                        {result.city}{result.city && result.state ? ', ' : ''}{result.state}
                        {result.union_name ? ` - ${result.union_name}` : ''}
                      </Text>
                    </View>
                  </TouchableOpacity>
                ))}
              </ScrollView>
            </View>
          )}
        </View>
      )}

      {/* Stats Bar */}
      {showStats && (
        <View style={styles.statsBar}>
          <View style={styles.statBadge}>
            <MaterialIcons name="layers" size={14} color={COLORS.primary} />
            <Text style={styles.statBadgeText}>{stats.territories.toLocaleString()} territories</Text>
          </View>
          <View style={styles.statBadge}>
            <MaterialIcons name="church" size={14} color={COLORS.primary} />
            <Text style={styles.statBadgeText}>{stats.churches.toLocaleString()} churches</Text>
          </View>
          {isLoading && (
            <ActivityIndicator size="small" color={COLORS.primary} style={{ marginLeft: 8 }} />
          )}
        </View>
      )}

      {/* Map */}
      <View style={styles.mapContainer}>
        {Platform.OS === 'web' ? (
          <iframe
            ref={mapRef}
            srcDoc={getMapHTML()}
            style={styles.webMap as any}
          />
        ) : (
          <View style={styles.nativeMapPlaceholder}>
            <MaterialIcons name="map" size={64} color={COLORS.text.secondary} />
            <Text style={styles.placeholderText}>
              Native map integration coming soon.
              {'\n'}Use the web version for full functionality.
            </Text>
          </View>
        )}
      </View>

      {/* Selected Feature Info Panel */}
      {renderSelectedFeatureInfo()}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  searchContainer: {
    position: 'absolute',
    top: SPACING.md,
    left: SPACING.md,
    right: SPACING.md,
    zIndex: 1000,
  },
  searchInputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.background,
    borderRadius: RADIUS.lg,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  searchInput: {
    flex: 1,
    marginLeft: SPACING.sm,
    fontSize: TYPOGRAPHY.md,
    color: COLORS.text.primary,
  },
  searchResults: {
    backgroundColor: COLORS.background,
    borderRadius: RADIUS.md,
    marginTop: SPACING.xs,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  searchResultItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  searchResultText: {
    marginLeft: SPACING.sm,
    flex: 1,
  },
  searchResultTitle: {
    fontSize: TYPOGRAPHY.md,
    fontWeight: '500',
    color: COLORS.text.primary,
  },
  searchResultSubtitle: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.text.secondary,
    marginTop: 2,
  },
  statsBar: {
    position: 'absolute',
    top: SPACING.md + 52,
    left: SPACING.md,
    flexDirection: 'row',
    alignItems: 'center',
    zIndex: 999,
  },
  statBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.95)',
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.md,
    marginRight: SPACING.xs,
  },
  statBadgeText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.text.secondary,
    marginLeft: 4,
  },
  mapContainer: {
    flex: 1,
  },
  webMap: {
    width: '100%',
    height: '100%',
    border: 'none',
  },
  nativeMapPlaceholder: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: COLORS.backgroundSecondary,
  },
  placeholderText: {
    fontSize: TYPOGRAPHY.md,
    color: COLORS.text.secondary,
    textAlign: 'center',
    marginTop: SPACING.md,
    paddingHorizontal: SPACING.xl,
  },
  infoPanel: {
    position: 'absolute',
    bottom: SPACING.md,
    left: SPACING.md,
    right: SPACING.md,
    backgroundColor: COLORS.background,
    borderRadius: RADIUS.lg,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: -2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 5,
  },
  infoPanelHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  infoPanelTitle: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: '600',
    color: COLORS.text.primary,
    flex: 1,
  },
  infoPanelBody: {
    padding: SPACING.md,
  },
  infoPanelLocation: {
    fontSize: TYPOGRAPHY.md,
    color: COLORS.text.secondary,
    marginBottom: SPACING.md,
  },
  infoPanelStats: {
    flexDirection: 'row',
    marginBottom: SPACING.md,
  },
  statItem: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: SPACING.sm,
    backgroundColor: COLORS.backgroundSecondary,
    borderRadius: RADIUS.md,
    marginRight: SPACING.sm,
  },
  statValue: {
    fontSize: TYPOGRAPHY.xl,
    fontWeight: '700',
    color: COLORS.primary,
  },
  statLabel: {
    fontSize: TYPOGRAPHY.xs,
    color: COLORS.text.secondary,
    marginTop: 2,
  },
  infoPanelMeta: {
    borderTopWidth: 1,
    borderTopColor: COLORS.border,
    paddingTop: SPACING.sm,
  },
  metaText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.text.secondary,
    marginBottom: 4,
  },
  metaLabel: {
    fontWeight: '500',
    color: COLORS.text.primary,
  },
});

export default GeoTerritoryMap;
