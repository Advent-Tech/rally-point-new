import React from 'react';
import MapLibreNativeTerritoryDrawing from './MapLibreNativeTerritoryDrawing';

// Default wrapper (native): uses MapLibre GL based MapLibreNativeTerritoryDrawing.
// On web, Expo will resolve TerritoryDrawingWrapper.web.tsx instead.
const TerritoryDrawingWrapper: React.FC<any> = (props) => {
  return <MapLibreNativeTerritoryDrawing {...props} />;
};

export default TerritoryDrawingWrapper;
