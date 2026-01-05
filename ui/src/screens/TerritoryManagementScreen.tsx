import React, { useState, useEffect, useCallback, useMemo, useRef } from "react";
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Platform,
  ScrollView,
  Modal,
  TextInput,
  Alert,
  StatusBar,
  Animated,
} from "react-native";
import { FontAwesome, MaterialIcons } from "@expo/vector-icons";
import * as DocumentPicker from "expo-document-picker";
import * as FileSystem from "expo-file-system";
import MobileTerritoryDrawing from "../components/MobileTerritoryDrawing";
import OfflineTerritoryMap from "../components/OfflineTerritoryMap";
import TerritoryTrackingMap from "../components/TerritoryTrackingMap";
import { realtimeLocationService } from "../services/RealtimeLocationService";
import Header from "../components/Header";

import { territoryService } from "../services/TerritoryService";

interface Territory {
  id: string;
  name: string;
  coordinates: Array<{ lat: number; lng: number }>;
  color: string;
  assignedWorker?: {
    id: string;
    name: string;
    email: string;
  };
  properties?: any;
}

interface Worker {
  id: string;
  name: string;
  email: string;
  currentLocation?: {
    latitude: number;
    longitude: number;
    accuracy?: number;
    timestamp?: number;
  };
  lastSeen?: number;
}

interface TerritoryManagementScreenProps {
  navigation: any;
}

export default function TerritoryManagementScreen({
  navigation,
}: TerritoryManagementScreenProps) {
  const [territories, setTerritories] = useState<Territory[]>([]);
  const [workers, setWorkers] = useState<Worker[]>([]);
  const [isDrawingMode, setIsDrawingMode] = useState(false);
  const [territoryName, setTerritoryName] = useState("");
  const [showImportModal, setShowImportModal] = useState(false);
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [showAssignTeamModal, setShowAssignTeamModal] = useState(false);
  const [selectedTerritory, setSelectedTerritory] = useState<Territory | null>(null);
  const [selectedWorker, setSelectedWorker] = useState<Worker | null>(null);
  const [selectedTeam, setSelectedTeam] = useState<{ teamId: string; teamName: string } | null>(null);
  const [teams, setTeams] = useState<{ teamId: string; teamName: string }[]>([]);
  const [mapReady, setMapReady] = useState(false);
  const [useOfflineMap, setUseOfflineMap] = useState(false);
  const [networkError, setNetworkError] = useState(false);
  const [showLiveLocationMap, setShowLiveLocationMap] = useState(false);
  const [activeWorkers, setActiveWorkers] = useState<Worker[]>([]);
  const [allTerritories, setAllTerritories] = useState<Territory[]>([]);
  const [filteredTerritories, setFilteredTerritories] = useState<Territory[]>([]);
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedUnion, setSelectedUnion] = useState<string>("");
  const [selectedConference, setSelectedConference] = useState<string>("");
  const [selectedChurch, setSelectedChurch] = useState<string>("");
  const [unions, setUnions] = useState<string[]>([]);
  const [conferences, setConferences] = useState<string[]>([]);
  const [churches, setChurches] = useState<string[]>([]);
  const [highlightIds, setHighlightIds] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);

  // New state for enhancements
  const [showTerritoryDetails, setShowTerritoryDetails] = useState<boolean>(false);
  const [selectedTerritoryDetails, setSelectedTerritoryDetails] = useState<Territory | null>(null);
  const [isFullScreenMap, setIsFullScreenMap] = useState<boolean>(false);
  const [showFAB, setShowFAB] = useState<boolean>(false);
  const [fabExpanded, setFabExpanded] = useState<boolean>(false);

  // Animation values for FAB
  const fabAnimation = useRef(new Animated.Value(0)).current;
  const fabRotation = useRef(new Animated.Value(0)).current;

  // Fetch teams (using service layer)
  const fetchTeams = async () => {
    try {
      console.log("🔄 Fetching teams...");
      // Teams will be fetched through TerritoryService
      setTeams([]);
    } catch (error) {
      console.error("❌ Error fetching teams:", error);
    }
  };

  // Fetch territories (using service layer)
  const fetchTerritories = async () => {
    console.log("🔄 Loading territories...");
    const startTime = Date.now();

    setIsLoading(true);

    try {
      console.log("🔄 Fetching territories from service...");
      const fetchedTerritories = await territoryService.getAllTerritories();

      console.log("✅ Fetched territories:", fetchedTerritories.length);

      if (fetchedTerritories.length === 0) {
        console.log("⚠️ No territories found. Creating sample data...");
        const sampleTerritories = createSampleTerritories();
        setTerritories(sampleTerritories);
        setAllTerritories(sampleTerritories);
        setFilteredTerritories(sampleTerritories);

        // Extract unique values for filters
        const uniqueUnions = [...new Set(sampleTerritories.map(t => t.properties?.Union).filter(Boolean))];
        const uniqueConferences = [...new Set(sampleTerritories.map(t => t.properties?.Conference).filter(Boolean))];
        const uniqueChurches = [...new Set(sampleTerritories.map(t => t.properties?.Entity).filter(Boolean))];

        setUnions(uniqueUnions);
        setConferences(uniqueConferences);
        setChurches(uniqueChurches);
      } else {
        setTerritories(fetchedTerritories);
        setAllTerritories(fetchedTerritories);
        setFilteredTerritories(fetchedTerritories);

        // Extract unique values for filters
        const uniqueUnions = [...new Set(fetchedTerritories.map(t => t.properties?.Union).filter(Boolean))];
        const uniqueConferences = [...new Set(fetchedTerritories.map(t => t.properties?.Conference).filter(Boolean))];
        const uniqueChurches = [...new Set(fetchedTerritories.map(t => t.properties?.Entity).filter(Boolean))];

        setUnions(uniqueUnions);
        setConferences(uniqueConferences);
        setChurches(uniqueChurches);
      }

      setNetworkError(false);
      setIsLoading(false);
    } catch (error) {
      console.error("❌ Error fetching territories:", error);
      setNetworkError(true);
      setUseOfflineMap(true);

      // Create sample data as fallback
      console.log("🔄 Creating sample data as fallback...");
      const sampleTerritories = createSampleTerritories();
      setTerritories(sampleTerritories);
      setAllTerritories(sampleTerritories);
      setFilteredTerritories(sampleTerritories);
      setIsLoading(false);
    }
  };

  // Create sample territories for demonstration
  const createSampleTerritories = (): Territory[] => {
    return [
      {
        id: "sample-1",
        name: "Mumbai Central Church",
        coordinates: [
          { lat: 19.0760, lng: 72.8777 },
          { lat: 19.0860, lng: 72.8877 },
          { lat: 19.0860, lng: 72.8677 },
          { lat: 19.0760, lng: 72.8677 }
        ],
        color: "#f59e0b",
        properties: {
          Union: "India Union",
          Conference: "Maharashtra Conference",
          Entity: "Mumbai Central Church",
          "Street Add": "123 Church Street, Mumbai",
          Zipcode: "400001",
          Population: "50000"
        }
      },
      {
        id: "sample-2",
        name: "Pune East Church",
        coordinates: [
          { lat: 18.5204, lng: 73.8567 },
          { lat: 18.5304, lng: 73.8667 },
          { lat: 18.5304, lng: 73.8467 },
          { lat: 18.5204, lng: 73.8467 }
        ],
        color: "#10b981",
        properties: {
          Union: "India Union",
          Conference: "Maharashtra Conference",
          Entity: "Pune East Church",
          "Street Add": "456 East Street, Pune",
          Zipcode: "411001",
          Population: "30000"
        }
      },
      {
        id: "sample-3",
        name: "Bangalore Central Church",
        coordinates: [
          { lat: 12.9716, lng: 77.5946 },
          { lat: 12.9816, lng: 77.6046 },
          { lat: 12.9816, lng: 77.5846 },
          { lat: 12.9716, lng: 77.5846 }
        ],
        color: "#3b82f6",
        properties: {
          Union: "India Union",
          Conference: "Karnataka Conference",
          Entity: "Bangalore Central Church",
          "Street Add": "789 Central Avenue, Bangalore",
          Zipcode: "560001",
          Population: "40000"
        }
      },
      {
        id: "sample-4",
        name: "Los Angeles Central Church",
        coordinates: [
          { lat: 34.0522, lng: -118.2437 },
          { lat: 34.0622, lng: -118.2337 },
          { lat: 34.0622, lng: -118.2537 },
          { lat: 34.0522, lng: -118.2537 }
        ],
        color: "#ef4444",
        properties: {
          Union: "USA Union",
          Conference: "California Conference",
          Entity: "Los Angeles Central Church",
          "Street Add": "123 Main Street, Los Angeles",
          Zipcode: "90001",
          Population: "60000"
        }
      }
    ];
  };



  // Fetch workers (using service layer)
  const fetchWorkers = async () => {
    try {
      console.log("🔄 Fetching workers...");
      // Workers will be fetched through service layer
      setWorkers([]);
    } catch (error) {
      console.error("❌ Error fetching workers:", error);
    }
  };

  useEffect(() => {
    console.log("🚀 TerritoryManagementScreen mounted, starting data fetch...");
    fetchTerritories();
    fetchWorkers();
    fetchTeams();
  }, []);

  // Smart search normalization function
  const normalizeSearchString = (str: string): string => {
    if (!str) return '';
    // Remove special characters (hyphens, apostrophes, etc.) and convert to lowercase
    return str
      .toLowerCase()
      .replace(/[-'`~!@#$%^&*()_+={}[\]|\\:;"<>,.?/]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  };

  // Filter territories based on smart search
  useEffect(() => {
    const handle = setTimeout(() => {
      let filtered = allTerritories;

      // Apply smart search filter
      if (searchTerm.trim()) {
        const normalizedSearchTerm = normalizeSearchString(searchTerm);

        filtered = filtered.filter(t => {
          const normalizedName = normalizeSearchString(t.name);
          const normalizedEntity = normalizeSearchString(t.properties?.Entity || '');
          const normalizedConference = normalizeSearchString(t.properties?.Conference || '');
          const normalizedUnion = normalizeSearchString(t.properties?.Union || '');

          return (
            normalizedName.includes(normalizedSearchTerm) ||
            normalizedEntity.includes(normalizedSearchTerm) ||
            normalizedConference.includes(normalizedSearchTerm) ||
            normalizedUnion.includes(normalizedSearchTerm)
          );
        });
      }

      // Only update filtered territories, not the main territories array
      setFilteredTerritories(filtered);
      const ids = (searchTerm.trim() ? filtered.map(t => t.id) : []);
      setHighlightIds(ids);
    }, 350);
    return () => clearTimeout(handle);
  }, [allTerritories, searchTerm]);

  // Sync map when filtered list changes - simplified to prevent loops
  const syncMapWithFiltered = useCallback(() => {
    if (Platform.OS === 'web' && mapReady) {
      const webView = document.querySelector('iframe');
      if (webView && webView.contentWindow) {
        webView.contentWindow.postMessage({
          type: 'renderTerritories',
          territories: filteredTerritories,
          highlightIds,
          layers: {
            union: true,
            conference: true,
            church: true,
          }
        }, '*');
      }
    }
  }, [mapReady]); // Removed filteredTerritories and highlightIds dependencies to prevent loops

  // Remove this useEffect that was causing infinite loops
  // The map sync will be called when needed (onLoad, etc.)
  // useEffect(() => {
  //   syncMapWithFiltered();
  // }, [syncMapWithFiltered]);



  // Start drawing mode
  const startDrawingMode = () => {
    console.log("🖊️ Starting drawing mode");
    setIsDrawingMode(true);

    if (Platform.OS === 'web' && mapReady) {
      const webView = document.querySelector('iframe');
      if (webView && webView.contentWindow) {
        webView.contentWindow.postMessage({ type: 'startDrawing' }, '*');
      }
    }
  };

  // Stop drawing mode
  const stopDrawingMode = () => {
    console.log("🛑 Stopping drawing mode");
    setIsDrawingMode(false);
    setTerritoryName("");

    if (Platform.OS === 'web' && mapReady) {
      const webView = document.querySelector('iframe');
      if (webView && webView.contentWindow) {
        webView.contentWindow.postMessage({ type: 'stopDrawing' }, '*');
      }
    }
  };

  // Handle map ready
  const handleMapReady = () => {
    console.log("🗺️ Map is ready");
    setMapReady(true);
  };

  // Draw territory on map
  const drawTerritoryOnMap = (territory: Territory) => {
    if (Platform.OS === 'web' && mapReady) {
      const webView = document.querySelector('iframe');
      if (webView && webView.contentWindow) {
        webView.contentWindow.postMessage({
          type: 'drawTerritory',
          territory: territory
        }, '*');
      }
    }
  };

  // Handle messages from map
  const handleMapMessage = (event: any) => {
    try {
      const data = JSON.parse(event.nativeEvent.data);

      if (data.type === 'polygonDrawn') {
        handlePolygonDrawn(data.coordinates);
      } else if (data.type === 'territoryClicked') {
        handleTerritoryClick(data.territoryId);
      }
    } catch (error) {
      console.error('Error handling map message:', error);
    }
  };

  // Handle territory click from map
  const handleTerritoryClick = (territoryId: string) => {
    console.log("🗺️ Territory clicked:", territoryId);
    const territory = territories.find(t => t.id === territoryId);
    if (territory) {
      setSelectedTerritoryDetails(territory);
      setShowTerritoryDetails(true);
    }
  };

  // Toggle full screen map
  const toggleFullScreenMap = () => {
    setIsFullScreenMap(!isFullScreenMap);
  };

  // Toggle FAB expansion with animation
  const toggleFAB = () => {
    const toValue = fabExpanded ? 0 : 1;

    Animated.parallel([
      Animated.spring(fabAnimation, {
        toValue,
        useNativeDriver: Platform.OS !== 'web',
        friction: Platform.OS === 'web' ? 8 : 5,
        tension: Platform.OS === 'web' ? 60 : 40,
      }),
      Animated.timing(fabRotation, {
        toValue,
        duration: Platform.OS === 'web' ? 200 : 300,
        useNativeDriver: Platform.OS !== 'web',
      }),
    ]).start();

    setFabExpanded(!fabExpanded);
  };

  // Handle FAB actions
  const handleFABImport = () => {
    setFabExpanded(false);
    setShowImportModal(true);
  };

  const handleFABDraw = () => {
    setFabExpanded(false);
    if (isDrawingMode) {
      stopDrawingMode();
    } else {
      startDrawingMode();
    }
  };

  // Handle polygon drawn
  const handlePolygonDrawn = async (coordinates: Array<{ lat: number; lng: number }>) => {
    console.log("🗺️ Processing drawn polygon with", coordinates.length, "coordinates");

    if (!territoryName.trim()) {
      Alert.alert(
        "Territory Name Required",
        "Please enter a territory name before drawing.",
        [{ text: "OK" }]
      );
      return;
    }

    if (coordinates.length < 3) {
      Alert.alert(
        "Invalid Territory",
        "Territory must have at least 3 points to form a valid area.",
        [{ text: "OK" }]
      );
      return;
    }

    try {
      const newTerritory = {
        name: territoryName.trim(),
        coordinates: coordinates,
        color: `#${Math.floor(Math.random()*16777215).toString(16)}`,
        createdAt: Date.now(),
        assignedWorker: null,
      };

      console.log("💾 Saving territory:", newTerritory.name);
      const territoryWithId = await territoryService.createTerritory(newTerritory);

      setTerritories((prev) => [...prev, territoryWithId]);
      setAllTerritories((prev) => [...prev, territoryWithId]);
      setFilteredTerritories((prev) => [...prev, territoryWithId]);

      // Draw on map if ready
      if (mapReady) {
        drawTerritoryOnMap(territoryWithId);
      }

      console.log("✅ Territory created successfully:", territoryWithId.name);

      // Reset drawing mode
      stopDrawingMode();

      Alert.alert(
        "Territory Created!",
        `Territory "${territoryWithId.name}" has been created successfully.`,
        [{ text: "Great!" }]
      );
    } catch (error) {
      console.error("❌ Error creating territory:", error);
      Alert.alert(
        "Creation Failed",
        "Failed to create territory. Please check your connection and try again.",
        [{ text: "OK" }]
      );
    }
  };

  // Create HTML for the map (avoiding template literal syntax issues)
  const getMapHTML = useMemo(() => {
    const htmlContent = [
      '<!DOCTYPE html>',
      '<html>',
      '<head>',
      '    <meta charset="utf-8" />',
      '    <meta name="viewport" content="width=device-width, initial-scale=1.0">',
      '    <title>Territory Management Map</title>',
      '    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />',
      '    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet.draw/1.0.4/leaflet.draw.css" />',
      '    <style>',
      '        body { margin: 0; padding: 0; }',
      '',
      '            L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {',
      '                attribution: "© OpenStreetMap contributors"',
      '            }).addTo(map);',
      '',
      '            drawnItems = new L.FeatureGroup();',
      '            map.addLayer(drawnItems);',
      '',
      '            drawControl = new L.Control.Draw({',
      '                position: "topright",',
      '                draw: {',
      '                    polygon: {',
      '                        allowIntersection: false,',
      '                        shapeOptions: { color: "#3b82f6", weight: 3, opacity: 0.8, fillOpacity: 0.2 }',
      '                    },',
      '                    rectangle: {',
      '                        shapeOptions: { color: "#3b82f6", weight: 3, opacity: 0.8, fillOpacity: 0.2 }',
      '                    },',
      '                    circle: false,',
      '                    circlemarker: false,',
      '                    marker: false,',
      '                    polyline: false',
      '                },',
      '                edit: { featureGroup: drawnItems, remove: true }',
      '            });',
      '',
      '            map.on(L.Draw.Event.CREATED, function (e) {',
      '                const layer = e.layer;',
      '                drawnItems.addLayer(layer);',
      '                let coordinates = [];',
      '                if (e.layerType === "polygon") {',
      '                    coordinates = layer.getLatLngs()[0].map(latlng => ({',
      '                        lat: latlng.lat,',
      '                        lng: latlng.lng',
      '                    }));',
      '                } else if (e.layerType === "rectangle") {',
      '                    const bounds = layer.getBounds();',
      '                    coordinates = [',
      '                        { lat: bounds.getNorth(), lng: bounds.getWest() },',
      '                        { lat: bounds.getNorth(), lng: bounds.getEast() },',
      '                        { lat: bounds.getSouth(), lng: bounds.getEast() },',
      '                        { lat: bounds.getSouth(), lng: bounds.getWest() }',
      '                    ];',
      '                }',
      '                window.ReactNativeWebView?.postMessage(JSON.stringify({',
      '                    type: "polygonDrawn",',
      '                    coordinates: coordinates',
      '                }));',
      '            });',
      '        }',
      '',
      '        function startDrawing() {',
      '            if (!isDrawingMode) {',
      '                map.addControl(drawControl);',
      '                isDrawingMode = true;',
      '            }',
      '        }',
      '',
      '        function stopDrawing() {',
      '            if (isDrawingMode) {',
      '                map.removeControl(drawControl);',
      '                drawnItems.clearLayers();',
      '                isDrawingMode = false;',
      '            }',
      '        }',
      '',
      '        function ensureLayers() {',
      '            if (!unionLayer) {',
      '                unionLayer = L.layerGroup().addTo(map);',
      '            }',
      '            if (!conferenceLayer) {',
      '                conferenceLayer = L.layerGroup().addTo(map);',
      '            }',
      '            if (!churchLayer) {',
      '                churchLayer = L.layerGroup().addTo(map);',
      '            }',
      '            if (!layersControl) {',
      '                layersControl = L.control.layers(null, {',
      '                    "Union Boundaries": unionLayer,',
      '                    "Conference Boundaries": conferenceLayer,',
      '                    "Church Territories": churchLayer',
      '                }).addTo(map);',
      '            }',
      '        }',
      '',
      '        function clearAllLayers() {',
      '            if (unionLayer) unionLayer.clearLayers();',
      '            if (conferenceLayer) conferenceLayer.clearLayers();',
      '            if (churchLayer) churchLayer.clearLayers();',
      '        }',
      '',
      '        function drawPolygonOnLayer(coords, style, targetLayer) {',
      '            const polygon = L.polygon(coords, style);',
      '            if (targetLayer) {',
      '                targetLayer.addLayer(polygon);',
      '            } else {',
      '                polygon.addTo(map);',
      '            }',
      '            return polygon;',
      '        }',
      '',
      '        function renderTerritoriesPayload(payload) {',
      '            ensureLayers();',
      '            clearAllLayers();',
      '            const territoriesData = payload.territories || [];',
      '            const highlightIds = new Set(payload.highlightIds || []);',
      '            const visibility = payload.layers || { union: true, conference: true, church: true };',
      '            try {',
      '                if (visibility.union) map.addLayer(unionLayer); else map.removeLayer(unionLayer);',
      '                if (visibility.conference) map.addLayer(conferenceLayer); else map.removeLayer(conferenceLayer);',
      '                if (visibility.church) map.addLayer(churchLayer); else map.removeLayer(churchLayer);',
      '            } catch (e) {',
      '                console.log("Layer visibility error:", e);',
      '            }',
      '            const bounds = [];',
      '            territoriesData.forEach(t => {',
      '                const props = t.properties || {};',
      '                const coords = (t.coordinates || []).map(pt => [pt.lat, pt.lng]);',
      '                if (!coords.length) return;',
      '                const isHighlighted = highlightIds.has(t.id);',
      '                const churchStyle = {',
      '                    color: isHighlighted ? "#ffd54f" : (t.color || "#f59e0b"),',
      '                    weight: isHighlighted ? 5 : 2,',
      '                    opacity: 0.9,',
      '                    fillOpacity: isHighlighted ? 0.35 : 0.2,',
      '                    fillColor: isHighlighted ? "#fff3cd" : (t.color || "#f59e0b")',
      '                };',
      '                const churchPoly = drawPolygonOnLayer(coords, churchStyle, churchLayer);',
      '                const popupHtml = [',
      '                    "<div class=\\"territory-popup\\">",',
      '                    "<div class=\\"territory-popup-name\\">" + (t.name || props.Entity || "Territory") + "</div>",',
      '                    "<div>🏛️ Church: " + (props.Entity || "-") + "</div>",',
      '                    "<div>🗺️ Conference: " + (props.Conference || "-") + "</div>",',
      '                    "<div>🌐 Union: " + (props.Union || "-") + "</div>",',
      '                    "<div>📬 Address: " + (props["Street Add"] || "-") + "</div>",',
      '                    "<div>📮 Zip: " + (props.Zipcode || "-") + "</div>",',
      '                    (props.Population ? "<div>👥 Pop: " + props.Population + "</div>" : ""),',
      '                    (props.Miles ? "<div>📏 Miles: " + props.Miles + "</div>" : ""),',
      '                    "</div>"',
      '                ].join("");',
      '                churchPoly.bindPopup(popupHtml);',
      '                ',
      '                // Add click handler for territory details',
      '                churchPoly.on("click", function() {',
      '                    window.ReactNativeWebView?.postMessage(JSON.stringify({',
      '                        type: "territoryClicked",',
      '                        territoryId: t.id',
      '                    }));',
      '                });',
      '                bounds.push(...coords);',
      '                const unionStyle = { color: "#2563eb", weight: 1.5, opacity: 0.8, fillOpacity: 0 };',
      '                drawPolygonOnLayer(coords, unionStyle, unionLayer);',
      '                const confStyle = { color: "#16a34a", weight: 1.5, opacity: 0.8, fillOpacity: 0 };',
      '                drawPolygonOnLayer(coords, confStyle, conferenceLayer);',
      '            });',
      '            if (bounds.length) {',
      '                const latlngs = bounds.map(b => L.latLng(b[0], b[1]));',
      '                const fit = L.latLngBounds(latlngs);',
      '                map.fitBounds(fit, { padding: [20, 20] });',
      '            }',
      '        }',
      '',
      '        function renderHierarchicalTerritories(payload) {',
      '            ensureLayers();',
      '            clearAllLayers();',
      '            const territoriesData = payload.territories || [];',
      '            const highlightIds = new Set(payload.highlightIds || []);',
      '            const level = payload.level || "union";',
      '            const bounds = [];',
      '',
      '            territoriesData.forEach(t => {',
      '                const props = t.properties || {};',
      '                const coords = (t.coordinates || []).map(pt => [pt.lat, pt.lng]);',
      '                if (!coords.length) return;',
      '                const isHighlighted = highlightIds.has(t.id);',
      '',
      '                let targetLayer, style, popupContent;',
      '',
      '                if (level === "union") {',
      '                    targetLayer = unionLayer;',
      '                    style = {',
      '                        color: isHighlighted ? "#ffd54f" : "#2563eb",',
      '                        weight: isHighlighted ? 4 : 3,',
      '                        opacity: 0.9,',
      '                        fillOpacity: isHighlighted ? 0.4 : 0.2,',
      '                        fillColor: isHighlighted ? "#dbeafe" : "#bfdbfe"',
      '                    };',
      '                    popupContent = [',
      '                        "<div class=\\"territory-popup\\">",',
      '                        "<div class=\\"territory-popup-name\\">🌐 " + (t.union || t.name) + "</div>",',
      '                        "<div>📊 Level: Union</div>",',
      '                        "<div>🏛️ Conferences: " + (t.childIds ? t.childIds.length : "0") + "</div>",',
      '                        "</div>"',
      '                    ].join("");',
      '                } else if (level === "conference") {',
      '                    targetLayer = conferenceLayer;',
      '                    style = {',
      '                        color: isHighlighted ? "#ffd54f" : "#16a34a",',
      '                        weight: isHighlighted ? 4 : 3,',
      '                        opacity: 0.9,',
      '                        fillOpacity: isHighlighted ? 0.4 : 0.25,',
      '                        fillColor: isHighlighted ? "#dcfce7" : "#bbf7d0"',
      '                    };',
      '                    popupContent = [',
      '                        "<div class=\\"territory-popup\\">",',
      '                        "<div class=\\"territory-popup-name\\">🗺️ " + (t.conference || t.name) + "</div>",',
      '                        "<div>📊 Level: Conference</div>",',
      '                        "<div>🌐 Union: " + (t.union || "-") + "</div>",',
      '                        "<div>🏛️ Churches: " + (t.childIds ? t.childIds.length : "0") + "</div>",',
      '                        "</div>"',
      '                    ].join("");',
      '                } else if (level === "church") {',
      '                    targetLayer = churchLayer;',
      '                    style = {',
      '                        color: isHighlighted ? "#ffd54f" : (t.color || "#f59e0b"),',
      '                        weight: isHighlighted ? 4 : 2,',
      '                        opacity: 0.9,',
      '                        fillOpacity: isHighlighted ? 0.4 : 0.3,',
      '                        fillColor: isHighlighted ? "#fef3c7" : (t.color || "#fed7aa")',
      '                    };',
      '                    popupContent = [',
      '                        "<div class=\\"territory-popup\\">",',
      '                        "<div class=\\"territory-popup-name\\">🏛️ " + (t.church || t.name) + "</div>",',
      '                        "<div>📊 Level: Church Territory</div>",',
      '                        "<div>🗺️ Conference: " + (t.conference || "-") + "</div>",',
      '                        "<div>🌐 Union: " + (t.union || "-") + "</div>",',
      '                        "<div>👤 Worker: " + (t.assignedWorker ? t.assignedWorker.name : "Unassigned") + "</div>",',
      '                        "<div>📬 Address: " + (props["Street Add"] || "-") + "</div>",',
      '                        (props.Population ? "<div>👥 Pop: " + props.Population + "</div>" : ""),',
      '                        "</div>"',
      '                    ].join("");',
      '                }',
      '',
      '                const polygon = drawPolygonOnLayer(coords, style, targetLayer);',
      '                polygon.bindPopup(popupContent);',
      '                bounds.push(...coords);',
      '',
      '                polygon.on("click", function() {',
      '                    if (level === "union") {',
      '                        window.ReactNativeWebView?.postMessage(JSON.stringify({',
      '                            type: "navigateToUnion",',
      '                            unionName: t.union || t.name',
      '                        }));',
      '                    } else if (level === "conference") {',
      '                        window.ReactNativeWebView?.postMessage(JSON.stringify({',
      '                            type: "navigateToConference",',
      '                            conferenceName: t.conference || t.name,',
      '                            unionName: t.union',
      '                        }));',
      '                    }',
      '                });',
      '            });',
      '',
      '            if (bounds.length) {',
      '                const latlngs = bounds.map(b => L.latLng(b[0], b[1]));',
      '                const fit = L.latLngBounds(latlngs);',
      '                map.fitBounds(fit, { padding: [20, 20] });',
      '            }',
      '        }',
      '',
      '        window.addEventListener("message", function(event) {',
      '            if (event.data.type === "startDrawing") {',
      '                startDrawing();',
      '            } else if (event.data.type === "stopDrawing") {',
      '                stopDrawing();',
      '            } else if (event.data.type === "renderTerritories") {',
      '                renderTerritoriesPayload(event.data);',
      '            } else if (event.data.type === "renderHierarchicalTerritories") {',
      '                renderHierarchicalTerritories(event.data);',
      '            } else if (event.data.type === "navigateToUnion") {',
      '                window.ReactNativeWebView?.postMessage(JSON.stringify({',
      '                    type: "hierarchicalNavigation",',
      '                    action: "navigateToUnion",',
      '                    unionName: event.data.unionName',
      '                }));',
      '            } else if (event.data.type === "navigateToConference") {',
      '                window.ReactNativeWebView?.postMessage(JSON.stringify({',
      '                    type: "hierarchicalNavigation",',
      '                    action: "navigateToConference",',
      '                    conferenceName: event.data.conferenceName,',
      '                    unionName: event.data.unionName',
      '                }));',
      '            } else if (event.data.type === "setLayerVisibility") {',
      '                ensureLayers();',
      '                const v = event.data.layers || { union: true, conference: true, church: true };',
      '                try {',
      '                    if (v.union) map.addLayer(unionLayer); else map.removeLayer(unionLayer);',
      '                    if (v.conference) map.addLayer(conferenceLayer); else map.removeLayer(conferenceLayer);',
      '                    if (v.church) map.addLayer(churchLayer); else map.removeLayer(churchLayer);',
      '                } catch (e) {',
      '                    console.log("Layer visibility error:", e);',
      '                }',
      '            }',
      '        });',
      '',
      '        document.addEventListener("DOMContentLoaded", initMap);',
      '    </script>',
      '</body>',
      '</html>'
    ];

    return htmlContent.join('\n');
  }, []);

  // Debug rendering state
  console.log("🔍 Rendering with state:", { isLoading, territories: territories.length });

  // Show loading screen
  if (isLoading) {
    return (
      <View style={styles.container}>
        <StatusBar barStyle="light-content" backgroundColor="#1e293b" />
        <Header
          title="Territory Management"
          showBackButton={true}
          onBackPress={() => {
            if (navigation.canGoBack()) {
              navigation.goBack();
            } else {
              navigation.navigate("AdminDashboard");
            }
          }}
        />
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>🔄 Loading Territory Data...</Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#1e293b" />

      <Header
        title="Territory Management"
        showBackButton={true}
        onBackPress={() => {
          if (navigation.canGoBack()) {
            navigation.goBack();
          } else {
            navigation.navigate("AdminDashboard");
          }
        }}
      />

      {/* ScrollView for entire content */}
      <ScrollView
        style={styles.scrollViewContainer}
        contentContainerStyle={styles.scrollViewContent}
        showsVerticalScrollIndicator={true}
      >
        {/* Error Message */}
        {networkError && (
          <View style={styles.errorContainer}>
            <Text style={styles.errorText}>⚠️ Network Error - Using Sample Data</Text>
          </View>
        )}

        {/* Drawing Controls */}
        {isDrawingMode && (
          <View style={styles.drawingControls}>
            <View style={styles.drawingHeader}>
              <Text style={styles.drawingTitle}>✏️ Draw New Territory</Text>
              <TouchableOpacity
                style={styles.cancelButton}
                onPress={stopDrawingMode}
              >
                <FontAwesome name="times" size={16} color="#ef4444" />
              </TouchableOpacity>
            </View>
            <TextInput
              style={styles.territoryNameInput}
              placeholder="Enter territory name..."
              placeholderTextColor="#94a3b8"
              value={territoryName}
              onChangeText={setTerritoryName}
            />
          </View>
        )}

        {/* Search Bar */}
        <View style={styles.filtersContainer}>
          <TextInput
            style={styles.searchInput}
            placeholder="Search territories..."
            placeholderTextColor="#94a3b8"
            value={searchTerm}
            onChangeText={setSearchTerm}
          />
        </View>

        {/* Map Container */}
        <View style={[styles.mapContainer, isFullScreenMap && styles.mapContainerFullScreen]}>
        {Platform.OS === 'web' ? (
          <iframe
            src={`data:text/html;charset=utf-8,${encodeURIComponent(getMapHTML)}`}
            style={{
              width: '100%',
              height: '100%',
              border: 0,
              borderRadius: isFullScreenMap ? '0px' : '8px',
            }}
            onLoad={() => {
              handleMapReady();
              setTimeout(() => {
                syncMapWithFiltered();
              }, 500);
            }}
            title="Territory Management Map"
          />
        ) : (
          <MobileTerritoryDrawing
            isDrawingMode={isDrawingMode}
            territoryName={territoryName}
            onTerritoryNameChange={setTerritoryName}
            onPolygonDrawn={handlePolygonDrawn}
            onStopDrawing={stopDrawingMode}
            territories={allTerritories}
            mapReady={mapReady}
            onMapReady={handleMapReady}
          />
        )}

          {/* Floating Full Screen Button */}
          <TouchableOpacity
            style={styles.fullScreenFloatingButton}
            onPress={toggleFullScreenMap}
          >
            <FontAwesome
              name={isFullScreenMap ? "compress" : "expand"}
              size={16}
              color="#002b5b"
            />
          </TouchableOpacity>
        </View>

        {/* Territory List - Hidden in full screen mode */}
        {!isFullScreenMap && (
          <View style={styles.territoryListContainer}>
        <Text style={styles.listTitle}>
          🗺️ Territories ({territories.length})
        </Text>
        {territories.map((territory) => (
          <TouchableOpacity
            key={territory.id}
            style={[
              styles.territoryItem,
              highlightIds.includes(territory.id) && styles.territoryItemHighlighted
            ]}
            onPress={() => {
              setSelectedTerritory(territory);
              setShowAssignModal(true);
            }}
          >
            <View style={styles.territoryInfo}>
              <View
                style={[
                  styles.colorIndicator,
                  { backgroundColor: territory.color },
                ]}
              />
              <View style={styles.territoryDetails}>
                <Text style={styles.territoryName}>
                  🏛️ {territory.name}
                </Text>

                {territory.properties?.Union && (
                  <Text style={styles.territoryHierarchy}>
                    🌐 Union: {territory.properties.Union}
                  </Text>
                )}

                {territory.properties?.Conference && (
                  <Text style={styles.territoryHierarchy}>
                    🗺️ Conference: {territory.properties.Conference}
                  </Text>
                )}

                {territory.properties?.Entity && (
                  <Text style={styles.territoryHierarchy}>
                    🏛️ Entity: {territory.properties.Entity}
                  </Text>
                )}

                <Text style={styles.territoryAssignment}>
                  {territory.assignedWorker
                    ? `👤 ${territory.assignedWorker.name}`
                    : "⚪ Unassigned"}
                </Text>

                {territory.assignedTeam && (
                  <Text style={[styles.territoryAssignment, { color: '#d7a638', marginTop: 4 }]}>
                    👥 Team: {territory.assignedTeam.teamName}
                  </Text>
                )}
              </View>
            </View>

            <View style={{ flexDirection: 'row', gap: 8 }}>
              <TouchableOpacity
                style={styles.assignButton}
                onPress={(e) => {
                  e.stopPropagation();
                  setSelectedTerritory(territory);
                  setShowAssignModal(true);
                }}
              >
                <MaterialIcons name="person-add" size={20} color="#3b82f6" />
              </TouchableOpacity>

              <TouchableOpacity
                style={[styles.assignButton, { backgroundColor: '#fef3c7' }]}
                onPress={(e) => {
                  e.stopPropagation();
                  setSelectedTerritory(territory);
                  setShowAssignTeamModal(true);
                }}
              >
                <MaterialIcons name="group-add" size={20} color="#d7a638" />
              </TouchableOpacity>
            </View>
          </TouchableOpacity>
        ))}
          </View>
        )}
      </ScrollView>

      {/* Floating Action Button */}
      <View style={styles.fabContainer}>
        {fabExpanded && (
          <>
            <Animated.View
              style={[
                styles.fabActionWrapper,
                {
                  opacity: fabAnimation,
                  transform: [
                    {
                      translateY: fabAnimation.interpolate({
                        inputRange: [0, 1],
                        outputRange: [20, 0],
                      }),
                    },
                  ],
                },
              ]}
            >
              <TouchableOpacity
                style={[styles.fabAction, styles.fabImport]}
                onPress={handleFABImport}
              >
                <FontAwesome name="upload" size={16} color="#ffffff" />
                <Text style={styles.fabActionText}>Import</Text>
              </TouchableOpacity>
            </Animated.View>
            <Animated.View
              style={[
                styles.fabActionWrapper,
                {
                  opacity: fabAnimation,
                  transform: [
                    {
                      translateY: fabAnimation.interpolate({
                        inputRange: [0, 1],
                        outputRange: [20, 0],
                      }),
                    },
                  ],
                },
              ]}
            >
              <TouchableOpacity
                style={[styles.fabAction, styles.fabDraw]}
                onPress={handleFABDraw}
              >
                <FontAwesome
                  name={isDrawingMode ? "stop" : "pencil"}
                  size={16}
                  color="#ffffff"
                />
                <Text style={styles.fabActionText}>
                  {isDrawingMode ? "Stop" : "Draw"}
                </Text>
              </TouchableOpacity>
            </Animated.View>
          </>
        )}
        <Animated.View
          style={{
            transform: [
              {
                rotate: fabRotation.interpolate({
                  inputRange: [0, 1],
                  outputRange: ['0deg', '45deg'],
                }),
              },
            ],
          }}
        >
          <TouchableOpacity
            style={styles.fabMain}
            onPress={toggleFAB}
          >
            <FontAwesome
              name="plus"
              size={20}
              color="#d7a638"
            />
          </TouchableOpacity>
        </Animated.View>
      </View>

      {/* Territory Details Modal */}
      <Modal
        visible={showTerritoryDetails}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowTerritoryDetails(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Territory Details</Text>
              <TouchableOpacity
                style={styles.modalCloseButton}
                onPress={() => setShowTerritoryDetails(false)}
              >
                <FontAwesome name="times" size={20} color="#64748b" />
              </TouchableOpacity>
            </View>

            {selectedTerritoryDetails && (
              <View style={styles.territoryDetailsContent}>
                <View style={styles.territoryDetailHeader}>
                  <View
                    style={[
                      styles.territoryDetailColorIndicator,
                      { backgroundColor: selectedTerritoryDetails.color },
                    ]}
                  />
                  <Text style={styles.territoryDetailName}>
                    {selectedTerritoryDetails.name}
                  </Text>
                </View>

                <View style={styles.territoryDetailSection}>
                  <Text style={styles.territoryDetailLabel}>Location Information</Text>
                  {selectedTerritoryDetails.properties?.Union && (
                    <View style={styles.territoryDetailRow}>
                      <Text style={styles.territoryDetailItemLabel}>Union:</Text>
                      <Text style={styles.territoryDetailItemValue}>
                        {selectedTerritoryDetails.properties.Union}
                      </Text>
                    </View>
                  )}
                  {selectedTerritoryDetails.properties?.Conference && (
                    <View style={styles.territoryDetailRow}>
                      <Text style={styles.territoryDetailItemLabel}>Conference:</Text>
                      <Text style={styles.territoryDetailItemValue}>
                        {selectedTerritoryDetails.properties.Conference}
                      </Text>
                    </View>
                  )}
                  {selectedTerritoryDetails.properties?.Entity && (
                    <View style={styles.territoryDetailRow}>
                      <Text style={styles.territoryDetailItemLabel}>Church/Entity:</Text>
                      <Text style={styles.territoryDetailItemValue}>
                        {selectedTerritoryDetails.properties.Entity}
                      </Text>
                    </View>
                  )}
                </View>

                <View style={styles.territoryDetailSection}>
                  <Text style={styles.territoryDetailLabel}>Assignment Status</Text>
                  <View style={styles.territoryDetailRow}>
                    <Text style={styles.territoryDetailItemLabel}>Worker:</Text>
                    <Text style={[
                      styles.territoryDetailItemValue,
                      selectedTerritoryDetails.assignedWorker ? styles.assignedStatus : styles.unassignedStatus
                    ]}>
                      {selectedTerritoryDetails.assignedWorker
                        ? selectedTerritoryDetails.assignedWorker.name
                        : "Unassigned"}
                    </Text>
                  </View>
                </View>

                {selectedTerritoryDetails.properties && (
                  <View style={styles.territoryDetailSection}>
                    <Text style={styles.territoryDetailLabel}>Additional Information</Text>
                    {selectedTerritoryDetails.properties["Street Add"] && (
                      <View style={styles.territoryDetailRow}>
                        <Text style={styles.territoryDetailItemLabel}>Address:</Text>
                        <Text style={styles.territoryDetailItemValue}>
                          {selectedTerritoryDetails.properties["Street Add"]}
                        </Text>
                      </View>
                    )}
                    {selectedTerritoryDetails.properties.Zipcode && (
                      <View style={styles.territoryDetailRow}>
                        <Text style={styles.territoryDetailItemLabel}>Zipcode:</Text>
                        <Text style={styles.territoryDetailItemValue}>
                          {selectedTerritoryDetails.properties.Zipcode}
                        </Text>
                      </View>
                    )}
                    {selectedTerritoryDetails.properties.Population && (
                      <View style={styles.territoryDetailRow}>
                        <Text style={styles.territoryDetailItemLabel}>Population:</Text>
                        <Text style={styles.territoryDetailItemValue}>
                          {selectedTerritoryDetails.properties.Population}
                        </Text>
                      </View>
                    )}
                  </View>
                )}

                <TouchableOpacity
                  style={styles.assignTerritoryButton}
                  onPress={() => {
                    setShowTerritoryDetails(false);
                    setSelectedTerritory(selectedTerritoryDetails);
                    setShowAssignModal(true);
                  }}
                >
                  <MaterialIcons name="person-add" size={18} color="#ffffff" />
                  <Text style={styles.assignTerritoryButtonText}>Assign Worker</Text>
                </TouchableOpacity>
              </View>
            )}
          </View>
        </View>
      </Modal>

      {/* Import Modal */}
      <Modal
        visible={showImportModal}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowImportModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>📁 Import Territories</Text>
              <TouchableOpacity
                style={styles.modalCloseButton}
                onPress={() => setShowImportModal(false)}
              >
                <FontAwesome name="times" size={20} color="#64748b" />
              </TouchableOpacity>
            </View>
            <Text style={styles.modalDescription}>
              Import territory data from GeoJSON, KMZ, or GPKG files.
            </Text>
            <TouchableOpacity
              style={styles.importConfirmButton}
              onPress={async () => {
                try {
                  const result = await DocumentPicker.getDocumentAsync({
                    type: ['application/json', 'application/vnd.google-earth.kmz'],
                    copyToCacheDirectory: true,
                  });

                  if (!result.canceled && result.assets[0]) {
                    console.log("📁 Selected file:", result.assets[0].name);
                    Alert.alert(
                      "Import Started",
                      `Processing ${result.assets[0].name}...`,
                      [{ text: "OK" }]
                    );
                    setShowImportModal(false);
                  }
                } catch (error) {
                  console.error("❌ Error importing file:", error);
                  Alert.alert(
                    "Import Failed",
                    "Failed to import file. Please try again.",
                    [{ text: "OK" }]
                  );
                }
              }}
            >
              <FontAwesome name="upload" size={16} color="#ffffff" />
              <Text style={styles.importConfirmButtonText}>Select File</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {/* Assignment Modal */}
      <Modal
        visible={showAssignModal}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowAssignModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>👤 Assign Territory</Text>
              <TouchableOpacity
                style={styles.modalCloseButton}
                onPress={() => setShowAssignModal(false)}
              >
                <FontAwesome name="times" size={20} color="#64748b" />
              </TouchableOpacity>
            </View>
            {selectedTerritory && (
              <Text style={styles.modalDescription}>
                Assign "{selectedTerritory.name}" to a worker:
              </Text>
            )}
            <ScrollView style={styles.workersList}>
              {workers.map((worker) => (
                <TouchableOpacity
                  key={worker.id}
                  style={[
                    styles.workerItem,
                    selectedWorker?.id === worker.id && styles.workerItemSelected,
                  ]}
                  onPress={() => setSelectedWorker(worker)}
                >
                  <Text style={styles.workerName}>{worker.name}</Text>
                  <Text style={styles.workerEmail}>{worker.email}</Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
            <TouchableOpacity
              style={[
                styles.assignConfirmButton,
                !selectedWorker && styles.buttonDisabled,
              ]}
              disabled={!selectedWorker}
              onPress={async () => {
                if (selectedTerritory && selectedWorker) {
                  try {
                    // Add loading state
                    console.log('🔄 Starting territory assignment...');
                    const startTime = Date.now();

                    await territoryService.assignTerritoryToWorker(
                      selectedTerritory.id,
                      {
                        id: selectedWorker.id,
                        name: selectedWorker.name,
                        email: selectedWorker.email,
                      }
                    );

                    // Update local state - batch state updates to prevent cascading loops
                    const updatedTerritory = {
                      ...selectedTerritory,
                      assignedWorker: {
                        id: selectedWorker.id,
                        name: selectedWorker.name,
                        email: selectedWorker.email,
                      },
                    };

                    // Use React.startTransition to batch updates and prevent infinite loops
                    React.startTransition(() => {
                      setAllTerritories((prev) =>
                        prev.map((t) => (t.id === selectedTerritory.id ? updatedTerritory : t))
                      );
                      setTerritories((prev) =>
                        prev.map((t) => (t.id === selectedTerritory.id ? updatedTerritory : t))
                      );
                      setFilteredTerritories((prev) =>
                        prev.map((t) => (t.id === selectedTerritory.id ? updatedTerritory : t))
                      );
                    });

                    Alert.alert(
                      "Assignment Successful!",
                      `Territory "${selectedTerritory.name}" has been assigned to ${selectedWorker.name}.`,
                      [{ text: "Great!" }]
                    );

                    const endTime = Date.now();
                    console.log(`✅ Territory assignment completed in ${endTime - startTime}ms`);

                    setShowAssignModal(false);
                    setSelectedTerritory(null);
                    setSelectedWorker(null);
                  } catch (error) {
                    console.error("❌ Error assigning territory:", error);
                    Alert.alert(
                      "Assignment Failed",
                      "Failed to assign territory. Please try again.",
                      [{ text: "OK" }]
                    );
                  }
                }
              }}
            >
              <MaterialIcons name="person-add" size={16} color="#ffffff" />
              <Text style={styles.assignConfirmButtonText}>Assign</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {/* Team Assignment Modal */}
      <Modal
        visible={showAssignTeamModal}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowAssignTeamModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>👥 Assign Territory to Team</Text>
              <TouchableOpacity
                style={styles.modalCloseButton}
                onPress={() => setShowAssignTeamModal(false)}
              >
                <FontAwesome name="times" size={20} color="#64748b" />
              </TouchableOpacity>
            </View>
            {selectedTerritory && (
              <Text style={styles.modalDescription}>
                Assign "{selectedTerritory.name}" to a team:
              </Text>
            )}
            <ScrollView style={styles.workersList}>
              {teams.length === 0 ? (
                <View style={{ padding: 20, alignItems: 'center' }}>
                  <Text style={{ color: '#64748b', textAlign: 'center' }}>
                    No teams available. Create a team first.
                  </Text>
                </View>
              ) : (
                teams.map((team) => (
                  <TouchableOpacity
                    key={team.teamId}
                    style={[
                      styles.workerItem,
                      selectedTeam?.teamId === team.teamId && styles.workerItemSelected,
                    ]}
                    onPress={() => setSelectedTeam(team)}
                  >
                    <Text style={styles.workerName}>{team.teamName}</Text>
                    <Text style={styles.workerEmail}>Team ID: {team.teamId}</Text>
                  </TouchableOpacity>
                ))
              )}
            </ScrollView>
            <TouchableOpacity
              style={[
                styles.assignConfirmButton,
                !selectedTeam && styles.buttonDisabled,
              ]}
              disabled={!selectedTeam}
              onPress={async () => {
                if (selectedTerritory && selectedTeam) {
                  try {
                    console.log('🔄 Assigning territory to team:', selectedTerritory.name, '→', selectedTeam.teamName);

                    // Use TerritoryService to assign territory to team
                    await territoryService.assignTerritoryToTeam(
                      selectedTerritory.id,
                      selectedTeam
                    );

                    // Update local state
                    const updatedTerritory = {
                      ...selectedTerritory,
                      assignedTeam: selectedTeam,
                    };

                    setTerritories((prev) =>
                      prev.map((t) => (t.id === selectedTerritory.id ? updatedTerritory : t))
                    );
                    setAllTerritories((prev) =>
                      prev.map((t) => (t.id === selectedTerritory.id ? updatedTerritory : t))
                    );
                    setFilteredTerritories((prev) =>
                      prev.map((t) => (t.id === selectedTerritory.id ? updatedTerritory : t))
                    );

                    console.log('✅ Territory assigned to team successfully');

                    Alert.alert(
                      "Assignment Successful!",
                      `Territory "${selectedTerritory.name}" has been assigned to team "${selectedTeam.teamName}".`,
                      [{ text: "Great!" }]
                    );

                    setShowAssignTeamModal(false);
                    setSelectedTerritory(null);
                    setSelectedTeam(null);
                  } catch (error) {
                    console.error("❌ Error assigning territory to team:", error);
                    Alert.alert(
                      "Assignment Failed",
                      "Failed to assign territory to team. Please try again.",
                      [{ text: "OK" }]
                    );
                  }
                }
              }}
            >
              <MaterialIcons name="group-add" size={16} color="#ffffff" />
              <Text style={styles.assignConfirmButtonText}>Assign to Team</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#f8fafc",
  },
  headerActions: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  importButton: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "rgba(215, 166, 56, 0.1)",
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: "#d7a638",
  },
  importButtonText: {
    color: "#d7a638",
    fontSize: 12,
    fontWeight: "600",
    marginLeft: 4,
  },
  drawButton: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#3b82f6",
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 6,
  },
  drawButtonActive: {
    backgroundColor: "#ef4444",
  },
  drawButtonText: {
    color: "#ffffff",
    fontSize: 12,
    fontWeight: "600",
    marginLeft: 4,
  },
  drawingControls: {
    backgroundColor: "#ffffff",
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: "#e2e8f0",
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  drawingHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 12,
  },
  drawingTitle: {
    fontSize: 16,
    fontWeight: "600",
    color: "#1e293b",
  },
  cancelButton: {
    padding: 4,
  },
  territoryNameInput: {
    borderWidth: 1,
    borderColor: "#d1d5db",
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
    color: "#1e293b",
    backgroundColor: "#ffffff",
  },
  filtersContainer: {
    backgroundColor: "#ffffff",
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: "#e2e8f0",
  },
  searchInput: {
    borderWidth: 1,
    borderColor: "#d1d5db",
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
    color: "#1e293b",
    backgroundColor: "#ffffff",
    marginBottom: 12,
  },
  layerTogglesRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-around",
  },
  toggleItem: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 8,
    paddingHorizontal: 12,
  },
  toggleBox: {
    width: 16,
    height: 16,
    borderRadius: 3,
    borderWidth: 2,
    borderColor: "#d1d5db",
    backgroundColor: "#ffffff",
    marginRight: 8,
  },
  toggleBoxOn: {
    backgroundColor: "#3b82f6",
    borderColor: "#3b82f6",
  },
  toggleLabel: {
    fontSize: 12,
    fontWeight: "500",
    color: "#64748b",
  },
  scrollViewContainer: {
    flex: 1,
  },
  scrollViewContent: {
    flexGrow: 1,
  },
  mapContainer: {
    height: 450,
    margin: 16,
    borderRadius: 8,
    overflow: "hidden",
    backgroundColor: "#ffffff",
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
    position: 'relative',
  },
  territoryListContainer: {
    backgroundColor: "#ffffff",
    borderTopWidth: 1,
    borderTopColor: "#e2e8f0",
    paddingBottom: 20,
  },
  listTitle: {
    fontSize: 16,
    fontWeight: "bold",
    color: "#1e293b",
    padding: 16,
    paddingBottom: 8,
  },
  territoryItem: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: "#f1f5f9",
  },
  territoryInfo: {
    flexDirection: "row",
    alignItems: "center",
    flex: 1,
  },
  colorIndicator: {
    width: 16,
    height: 16,
    borderRadius: 8,
    marginRight: 12,
  },
  territoryDetails: {
    flex: 1,
  },
  territoryNameRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 2,
  },
  territoryName: {
    fontSize: 16,
    fontWeight: "600",
    color: "#1e293b",
    flex: 1,
  },
  territoryAssignment: {
    fontSize: 14,
    color: "#64748b",
    marginBottom: 2,
  },
  assignButton: {
    padding: 8,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: "rgba(0, 0, 0, 0.5)",
    justifyContent: "center",
    alignItems: "center",
  },
  modalContent: {
    backgroundColor: "#ffffff",
    borderRadius: 12,
    padding: 24,
    margin: 20,
    maxWidth: 400,
    width: "90%",
    maxHeight: "80%",
  },
  modalHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 16,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: "bold",
    color: "#1e293b",
  },
  modalCloseButton: {
    padding: 4,
  },
  modalDescription: {
    fontSize: 14,
    color: "#64748b",
    marginBottom: 20,
    lineHeight: 20,
  },
  importConfirmButton: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#3b82f6",
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 8,
  },
  importConfirmButtonText: {
    color: "#ffffff",
    fontSize: 16,
    fontWeight: "600",
    marginLeft: 8,
  },
  workersList: {
    maxHeight: 200,
    marginBottom: 20,
  },
  workerItem: {
    padding: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: "#e2e8f0",
    marginBottom: 8,
  },
  workerItemSelected: {
    borderColor: "#3b82f6",
    backgroundColor: "#eff6ff",
  },
  workerName: {
    fontSize: 16,
    fontWeight: "600",
    color: "#1e293b",
    marginBottom: 4,
  },
  workerEmail: {
    fontSize: 14,
    color: "#64748b",
  },
  assignConfirmButton: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#10b981",
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 8,
  },
  assignConfirmButtonText: {
    color: "#ffffff",
    fontSize: 16,
    fontWeight: "600",
    marginLeft: 8,
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  territoryItemHighlighted: {
    backgroundColor: "#fef3c7",
    borderLeftWidth: 4,
    borderLeftColor: "#f59e0b",
  },
  territoryHierarchy: {
    fontSize: 12,
    color: "#64748b",
    marginBottom: 2,
  },
  // Loading and Error Styles
  loadingContainer: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    padding: 20,
  },
  loadingText: {
    fontSize: 18,
    fontWeight: "600",
    color: "#1e293b",
    marginBottom: 8,
  },
  errorContainer: {
    backgroundColor: "#fef2f2",
    borderLeftWidth: 4,
    borderLeftColor: "#ef4444",
    padding: 12,
    margin: 16,
    borderRadius: 8,
  },
  errorText: {
    fontSize: 14,
    fontWeight: "600",
    color: "#dc2626",
  },
  // Full Screen Map Styles
  mapContainerFullScreen: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    zIndex: 10,
    height: '100%',
    flex: 1,
  },
  fullScreenFloatingButton: {
    position: 'absolute',
    bottom: 20,
    left: 20,
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#ffffff',
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 6,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
    zIndex: 900,
  },
  // FAB Styles
  fabContainer: {
    position: 'absolute',
    bottom: 20,
    right: 20,
    alignItems: 'center',
    zIndex: 1000,
  },
  fabMain: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#ffffff',
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
  },
  fabActionWrapper: {
    marginBottom: 12,
  },
  fabAction: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 24,
    elevation: 6,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
  },
  fabImport: {
    backgroundColor: '#3b82f6',
  },
  fabDraw: {
    backgroundColor: '#10b981',
  },
  fabActionText: {
    color: '#ffffff',
    fontSize: 14,
    fontWeight: '600',
    marginLeft: 8,
  },
  // Territory Details Modal Styles
  territoryDetailsContent: {
    maxHeight: '70%',
  },
  territoryDetailHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 20,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
  },
  territoryDetailColorIndicator: {
    width: 16,
    height: 16,
    borderRadius: 8,
    marginRight: 12,
  },
  territoryDetailName: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1e293b',
    flex: 1,
  },
  territoryDetailSection: {
    marginBottom: 16,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#f1f5f9',
  },
  territoryDetailLabel: {
    fontSize: 13,
    fontWeight: '700',
    color: '#002b5b',
    marginBottom: 10,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  territoryDetailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 6,
  },
  territoryDetailItemLabel: {
    fontSize: 14,
    color: '#64748b',
    fontWeight: '500',
    flex: 0.4,
  },
  territoryDetailItemValue: {
    fontSize: 14,
    color: '#1e293b',
    fontWeight: '400',
    flex: 0.6,
    textAlign: 'right',
  },
  assignedStatus: {
    color: '#10b981',
    fontWeight: '600',
  },
  unassignedStatus: {
    color: '#ef4444',
    fontWeight: '600',
  },
  assignTerritoryButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#002b5b',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 8,
    marginTop: 12,
  },
  assignTerritoryButtonText: {
    color: '#ffffff',
    fontSize: 15,
    fontWeight: '600',
    marginLeft: 6,
  },
});
