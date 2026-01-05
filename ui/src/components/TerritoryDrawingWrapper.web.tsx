import React from 'react';
import ModernTerritoryDrawing from './ModernTerritoryDrawing';

// Web-only wrapper: use Leaflet-based ModernTerritoryDrawing on web
const TerritoryDrawingWrapper: React.FC<any> = (props) => {
  return <ModernTerritoryDrawing {...props} />;
};

export default TerritoryDrawingWrapper;
