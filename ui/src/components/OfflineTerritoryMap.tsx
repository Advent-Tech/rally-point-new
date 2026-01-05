import React, { useEffect, useRef, useState } from 'react';
import { View, StyleSheet, Platform } from 'react-native';

interface Territory {
  id: string;
  name: string;
  coordinates: Array<{lat: number, lng: number}>;
  color: string;
  assignedWorker?: {
    id: string;
    name: string;
    email: string;
  };
}

interface OfflineTerritoryMapProps {
  territories: Territory[];
  isDrawingMode: boolean;
  onPolygonDrawn: (coordinates: Array<{lat: number, lng: number}>) => void;
  onMapReady: () => void;
}

const OfflineTerritoryMap: React.FC<OfflineTerritoryMapProps> = ({
  territories,
  isDrawingMode,
  onPolygonDrawn,
  onMapReady,
}) => {
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const [mapReady, setMapReady] = useState(false);

  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      console.log('📨 Offline map message:', event.data);
      
      if (event.data.type === 'mapReady') {
        setMapReady(true);
        onMapReady();
      } else if (event.data.type === 'polygonDrawn') {
        onPolygonDrawn(event.data.coordinates);
      }
    };

    if (Platform.OS === 'web') {
      window.addEventListener('message', handleMessage);
      return () => {
        window.removeEventListener('message', handleMessage);
      };
    }
  }, [onMapReady, onPolygonDrawn]);

  useEffect(() => {
    if (mapReady && iframeRef.current) {
      // Send drawing mode state
      iframeRef.current.contentWindow?.postMessage({
        type: isDrawingMode ? 'startDrawing' : 'stopDrawing'
      }, '*');
    }
  }, [isDrawingMode, mapReady]);

  useEffect(() => {
    if (mapReady && iframeRef.current) {
      // Draw existing territories
      territories.forEach(territory => {
        iframeRef.current?.contentWindow?.postMessage({
          type: 'drawTerritory',
          territory: territory
        }, '*');
      });
    }
  }, [territories, mapReady]);

  const getOfflineMapHTML = () => `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body { 
                margin: 0; 
                padding: 0; 
                font-family: Arial, sans-serif;
                background: #f0f9ff;
                overflow: hidden;
            }
            #map { 
                height: 100vh; 
                width: 100%; 
                position: relative;
                background: linear-gradient(135deg, #e0f2fe 0%, #b3e5fc 100%);
            }
            #drawing-canvas {
                position: absolute;
                top: 0;
                left: 0;
                z-index: 1000;
                cursor: default;
                pointer-events: none;
            }
            .map-controls {
                position: absolute;
                top: 20px;
                right: 20px;
                z-index: 2000;
                display: flex;
                flex-direction: column;
                gap: 10px;
            }
            .control-button {
                background: white;
                border: 2px solid rgba(0,0,0,0.2);
                border-radius: 4px;
                width: 40px;
                height: 40px;
                display: flex;
                align-items: center;
                justify-content: center;
                cursor: pointer;
                font-size: 18px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                transition: all 0.2s;
            }
            .control-button:hover {
                background: #f4f4f4;
                transform: translateY(-1px);
                box-shadow: 0 4px 8px rgba(0,0,0,0.15);
            }
            .control-button.active {
                background: #002b5b;
                color: white;
            }
            .map-info {
                position: absolute;
                bottom: 20px;
                left: 20px;
                background: rgba(255,255,255,0.9);
                padding: 10px 15px;
                border-radius: 8px;
                font-size: 12px;
                color: #333;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            .territory-popup {
                position: absolute;
                background: white;
                border-radius: 8px;
                padding: 10px;
                box-shadow: 0 4px 12px rgba(0,0,0,0.15);
                font-size: 14px;
                z-index: 1500;
                pointer-events: none;
                transform: translate(-50%, -100%);
                margin-top: -10px;
            }
            .territory-popup::after {
                content: '';
                position: absolute;
                top: 100%;
                left: 50%;
                transform: translateX(-50%);
                border: 6px solid transparent;
                border-top-color: white;
            }
            .territory-popup-name {
                font-weight: bold;
                color: #002b5b;
                margin-bottom: 4px;
            }
            .territory-popup-worker {
                font-size: 12px;
                color: #64748b;
            }
            .drawing-instructions {
                position: absolute;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                background: rgba(0, 43, 91, 0.9);
                color: white;
                padding: 20px;
                border-radius: 12px;
                text-align: center;
                font-size: 16px;
                z-index: 1000;
                display: none;
            }
            .drawing-instructions.show {
                display: block;
            }
        </style>
    </head>
    <body>
        <div id="map">
            <canvas id="drawing-canvas"></canvas>
            
            <div class="map-controls">
                <div class="control-button" id="polygon-btn" title="Draw Polygon">⬟</div>
                <div class="control-button" id="rectangle-btn" title="Draw Rectangle">⬜</div>
                <div class="control-button" id="clear-btn" title="Clear Drawing">🗑️</div>
            </div>
            
            <div class="map-info">
                <div>🗺️ Offline Territory Drawing</div>
                <div>Click and drag to draw territory boundaries</div>
            </div>
            
            <div class="drawing-instructions" id="instructions">
                <div>✏️ Drawing Mode Active</div>
                <div style="margin-top: 10px; font-size: 14px;">
                    Click points to create territory boundary<br>
                    Double-click to finish drawing
                </div>
            </div>
        </div>

        <script>
            let canvas = null;
            let ctx = null;
            let isDrawing = false;
            let drawingMode = 'polygon'; // 'polygon' or 'rectangle'
            let currentPath = [];
            let territories = [];
            let isMouseDown = false;
            let startPoint = null;

            function initMap() {
                console.log('🗺️ Initializing offline territory map');
                
                canvas = document.getElementById('drawing-canvas');
                canvas.width = window.innerWidth;
                canvas.height = window.innerHeight;
                ctx = canvas.getContext('2d');
                
                // Set up drawing styles
                ctx.strokeStyle = '#002b5b';
                ctx.lineWidth = 3;
                ctx.fillStyle = 'rgba(0, 43, 91, 0.3)';
                ctx.lineCap = 'round';
                ctx.lineJoin = 'round';
                
                // Add event listeners
                canvas.addEventListener('click', handleCanvasClick);
                canvas.addEventListener('dblclick', finishDrawing);
                canvas.addEventListener('mousedown', handleMouseDown);
                canvas.addEventListener('mousemove', handleMouseMove);
                canvas.addEventListener('mouseup', handleMouseUp);
                
                // Control buttons
                document.getElementById('polygon-btn').addEventListener('click', () => setDrawingMode('polygon'));
                document.getElementById('rectangle-btn').addEventListener('click', () => setDrawingMode('rectangle'));
                document.getElementById('clear-btn').addEventListener('click', clearCanvas);
                
                // Handle window resize
                window.addEventListener('resize', handleResize);
                
                console.log('✅ Offline territory map initialized');
                
                // Notify parent
                window.parent.postMessage({ type: 'mapReady' }, '*');
            }

            function setDrawingMode(mode) {
                drawingMode = mode;
                document.querySelectorAll('.control-button').forEach(btn => btn.classList.remove('active'));
                document.getElementById(mode + '-btn').classList.add('active');
                console.log('🎨 Drawing mode set to:', mode);
            }

            function handleCanvasClick(e) {
                if (!isDrawing) return;
                
                const rect = canvas.getBoundingClientRect();
                const x = e.clientX - rect.left;
                const y = e.clientY - rect.top;
                
                if (drawingMode === 'polygon') {
                    addPolygonPoint(x, y);
                }
            }

            function handleMouseDown(e) {
                if (!isDrawing || drawingMode !== 'rectangle') return;
                
                isMouseDown = true;
                const rect = canvas.getBoundingClientRect();
                startPoint = {
                    x: e.clientX - rect.left,
                    y: e.clientY - rect.top
                };
            }

            function handleMouseMove(e) {
                if (!isDrawing || !isMouseDown || drawingMode !== 'rectangle') return;
                
                const rect = canvas.getBoundingClientRect();
                const currentPoint = {
                    x: e.clientX - rect.left,
                    y: e.clientY - rect.top
                };
                
                // Clear and redraw
                redrawCanvas();
                drawRectanglePreview(startPoint, currentPoint);
            }

            function handleMouseUp(e) {
                if (!isDrawing || !isMouseDown || drawingMode !== 'rectangle') return;
                
                isMouseDown = false;
                const rect = canvas.getBoundingClientRect();
                const endPoint = {
                    x: e.clientX - rect.left,
                    y: e.clientY - rect.top
                };
                
                finishRectangle(startPoint, endPoint);
            }

            function addPolygonPoint(x, y) {
                currentPath.push({ x, y });
                
                if (currentPath.length === 1) {
                    ctx.beginPath();
                    ctx.moveTo(x, y);
                } else {
                    ctx.lineTo(x, y);
                    ctx.stroke();
                }
                
                // Draw point marker
                ctx.beginPath();
                ctx.arc(x, y, 4, 0, 2 * Math.PI);
                ctx.fillStyle = '#d7a638';
                ctx.fill();
                ctx.fillStyle = 'rgba(0, 43, 91, 0.3)';
            }

            function drawRectanglePreview(start, end) {
                ctx.strokeStyle = '#002b5b';
                ctx.lineWidth = 2;
                ctx.setLineDash([5, 5]);
                ctx.strokeRect(start.x, start.y, end.x - start.x, end.y - start.y);
                ctx.setLineDash([]);
            }

            function finishRectangle(start, end) {
                const coordinates = [
                    { lat: 40.7128 + (start.y - canvas.height/2) * 0.0001, lng: -74.0060 + (start.x - canvas.width/2) * 0.0001 },
                    { lat: 40.7128 + (start.y - canvas.height/2) * 0.0001, lng: -74.0060 + (end.x - canvas.width/2) * 0.0001 },
                    { lat: 40.7128 + (end.y - canvas.height/2) * 0.0001, lng: -74.0060 + (end.x - canvas.width/2) * 0.0001 },
                    { lat: 40.7128 + (end.y - canvas.height/2) * 0.0001, lng: -74.0060 + (start.x - canvas.width/2) * 0.0001 }
                ];
                
                sendPolygonToParent(coordinates);
                clearCurrentDrawing();
            }

            function finishDrawing() {
                if (!isDrawing || currentPath.length < 3) return;
                
                // Close the polygon
                ctx.closePath();
                ctx.fill();
                ctx.stroke();
                
                // Convert to coordinates
                const coordinates = currentPath.map(point => ({
                    lat: 40.7128 + (point.y - canvas.height/2) * 0.0001,
                    lng: -74.0060 + (point.x - canvas.width/2) * 0.0001
                }));
                
                sendPolygonToParent(coordinates);
                clearCurrentDrawing();
            }

            function sendPolygonToParent(coordinates) {
                console.log('🗺️ Sending polygon with', coordinates.length, 'points');
                window.parent.postMessage({
                    type: 'polygonDrawn',
                    coordinates: coordinates
                }, '*');
            }

            function clearCurrentDrawing() {
                currentPath = [];
                startPoint = null;
                isMouseDown = false;
            }

            function clearCanvas() {
                ctx.clearRect(0, 0, canvas.width, canvas.height);
                redrawTerritories();
                clearCurrentDrawing();
            }

            function redrawCanvas() {
                ctx.clearRect(0, 0, canvas.width, canvas.height);
                redrawTerritories();
                
                // Redraw current path
                if (currentPath.length > 0) {
                    ctx.beginPath();
                    ctx.moveTo(currentPath[0].x, currentPath[0].y);
                    for (let i = 1; i < currentPath.length; i++) {
                        ctx.lineTo(currentPath[i].x, currentPath[i].y);
                    }
                    ctx.stroke();
                    
                    // Redraw points
                    currentPath.forEach(point => {
                        ctx.beginPath();
                        ctx.arc(point.x, point.y, 4, 0, 2 * Math.PI);
                        ctx.fillStyle = '#d7a638';
                        ctx.fill();
                    });
                    ctx.fillStyle = 'rgba(0, 43, 91, 0.3)';
                }
            }

            function startDrawing() {
                console.log('✏️ Starting drawing mode');
                isDrawing = true;
                canvas.style.pointerEvents = 'auto';
                canvas.style.cursor = 'crosshair';
                document.getElementById('instructions').classList.add('show');
                setDrawingMode('polygon');
            }

            function stopDrawing() {
                console.log('🛑 Stopping drawing mode');
                isDrawing = false;
                canvas.style.pointerEvents = 'none';
                canvas.style.cursor = 'default';
                document.getElementById('instructions').classList.remove('show');
                clearCurrentDrawing();
                document.querySelectorAll('.control-button').forEach(btn => btn.classList.remove('active'));
            }

            function drawTerritory(territory) {
                console.log('🗺️ Drawing territory:', territory.name);
                
                if (!territory.coordinates || territory.coordinates.length < 3) return;
                
                // Convert coordinates to canvas points
                const canvasPoints = territory.coordinates.map(coord => ({
                    x: canvas.width/2 + (coord.lng + 74.0060) * 10000,
                    y: canvas.height/2 - (coord.lat - 40.7128) * 10000
                }));
                
                // Draw territory
                ctx.beginPath();
                ctx.moveTo(canvasPoints[0].x, canvasPoints[0].y);
                for (let i = 1; i < canvasPoints.length; i++) {
                    ctx.lineTo(canvasPoints[i].x, canvasPoints[i].y);
                }
                ctx.closePath();
                
                ctx.fillStyle = territory.color + '40';
                ctx.strokeStyle = territory.color;
                ctx.lineWidth = 2;
                ctx.fill();
                ctx.stroke();
                
                // Add label
                const centerX = canvasPoints.reduce((sum, p) => sum + p.x, 0) / canvasPoints.length;
                const centerY = canvasPoints.reduce((sum, p) => sum + p.y, 0) / canvasPoints.length;
                
                ctx.fillStyle = '#000';
                ctx.font = 'bold 14px Arial';
                ctx.textAlign = 'center';
                ctx.fillText(territory.name, centerX, centerY);
                
                if (territory.assignedWorker) {
                    ctx.font = '12px Arial';
                    ctx.fillText('👤 ' + territory.assignedWorker.name, centerX, centerY + 16);
                }
                
                territories.push(territory);
            }

            function redrawTerritories() {
                territories.forEach(territory => {
                    drawTerritory(territory);
                });
            }

            function handleResize() {
                canvas.width = window.innerWidth;
                canvas.height = window.innerHeight;
                redrawCanvas();
            }

            // Listen for messages
            window.addEventListener('message', function(event) {
                const data = event.data;
                if (data.type === 'startDrawing') {
                    startDrawing();
                } else if (data.type === 'stopDrawing') {
                    stopDrawing();
                } else if (data.type === 'drawTerritory') {
                    drawTerritory(data.territory);
                }
            });

            // Initialize
            document.addEventListener('DOMContentLoaded', initMap);
            if (document.readyState !== 'loading') {
                initMap();
            }
        </script>
    </body>
    </html>
  `;

  if (Platform.OS !== 'web') {
    return null;
  }

  return (
    <View style={styles.container}>
      <iframe
        ref={iframeRef}
        srcDoc={getOfflineMapHTML()}
        style={styles.iframe}
        title="Offline Territory Map"
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  iframe: {
    width: '100%',
    height: '100%',
    border: 'none',
  } as any,
});

export default OfflineTerritoryMap;
