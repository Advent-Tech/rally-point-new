import { Platform } from 'react-native';

// API base URL - API Gateway runs on port 8080
const API_BASE_URL = __DEV__
  ? Platform.select({
      android: 'http://10.0.2.2:8080',
      default: 'http://localhost:8080',
    })!
  : 'https://api.rallypoint.app';

// Types for geo territory data
export interface GeoTerritory {
  id: string;
  fid: number;
  solid: string;
  entity_name: string;
  entity_id: string;
  group_id?: string;
  address?: string;
  street_address?: string;
  city?: string;
  county?: string;
  state?: string;
  zipcode?: string;
  population?: number;
  housing_units?: number;
  union_name?: string;
  conference?: string;
  geoid?: string;
  geometry?: any; // GeoJSON geometry
}

export interface GeoTerritorySimple {
  id: string;
  solid: string;
  entity_name: string;
  entity_id: string;
  city?: string;
  state?: string;
  union_name?: string;
  conference?: string;
  population?: number;
}

export interface ChurchLocation {
  entity_id: string;
  entity_name: string;
  union_name?: string;
  conference?: string;
  address?: string;
  city?: string;
  state?: string;
  latitude: number;
  longitude: number;
  territory_count: number;
  total_population: number;
  total_housing: number;
}

export interface UnionStats {
  union_name: string;
  territory_count: number;
  church_count: number;
  conference_count: number;
  total_population: number;
  total_housing: number;
}

export interface ConferenceStats {
  conference: string;
  union_name: string;
  territory_count: number;
  church_count: number;
  total_population: number;
  total_housing: number;
}

export interface GeoJSONFeatureCollection {
  type: 'FeatureCollection';
  features: GeoJSONFeature[];
}

export interface GeoJSONFeature {
  type: 'Feature';
  id: string;
  geometry: any;
  properties: Record<string, any>;
}

export interface BoundsQuery {
  minLng: number;
  minLat: number;
  maxLng: number;
  maxLat: number;
  limit?: number;
  zoom?: number;
}

// Territory Assignment Types
export interface TerritoryAssignment {
  id: string;
  territory_id: string;
  territory_solid: string;
  team_id: string;
  assigned_worker_id?: string;
  assigned_by: string;
  assigned_at: string;
  expires_at?: string;
  status: 'active' | 'completed' | 'paused' | 'cancelled';
  priority: 'high' | 'medium' | 'low';
  notes?: string;
  last_worked_at?: string;
  visits_count: number;
  completeness_percentage: number;
}

export interface TerritoryAssignmentWithDetails extends TerritoryAssignment {
  entity_name: string;
  entity_id: string;
  city?: string;
  state?: string;
  union_name?: string;
  conference?: string;
  population?: number;
  housing_units?: number;
  geometry?: any;
}

export interface CreateAssignmentRequest {
  territory_id: string;
  team_id: string;
  assigned_worker_id?: string;
  assigned_by: string;
  priority?: 'high' | 'medium' | 'low';
  notes?: string;
  expires_at?: string;
}

export interface UpdateAssignmentRequest {
  assigned_worker_id?: string;
  status?: 'active' | 'completed' | 'paused' | 'cancelled';
  priority?: 'high' | 'medium' | 'low';
  notes?: string;
  visits_count?: number;
  completeness_percentage?: number;
}

export interface TerritorySearchQuery {
  query?: string;
  union?: string;
  conference?: string;
  state?: string;
  city?: string;
  limit?: number;
  offset?: number;
}

class GeoTerritoryService {
  /**
   * Get territories within geographic bounds as GeoJSON
   */
  async getTerritoriesInBounds(bounds: BoundsQuery): Promise<GeoJSONFeatureCollection> {
    const boundsStr = `${bounds.minLng},${bounds.minLat},${bounds.maxLng},${bounds.maxLat}`;
    const params = new URLSearchParams({
      bounds: boundsStr,
      limit: String(bounds.limit || 1000),
      zoom: String(bounds.zoom || 10),
    });

    const url = `${API_BASE_URL}/api/geo/territories?${params}`;
    console.log(`🗺️ Fetching territories in bounds: ${boundsStr}`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch territories: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Get territories at a specific point (lat/lng)
   */
  async getTerritoriesAtPoint(lat: number, lng: number): Promise<{
    lat: number;
    lng: number;
    territories: GeoTerritory[];
    count: number;
  }> {
    const url = `${API_BASE_URL}/api/geo/territories/at?lat=${lat}&lng=${lng}`;
    console.log(`📍 Fetching territories at point: ${lat}, ${lng}`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch territories at point: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Get a single territory by ID
   */
  async getTerritoryById(id: string): Promise<GeoTerritory> {
    const url = `${API_BASE_URL}/api/geo/territories/${id}`;
    console.log(`🏛️ Fetching territory by ID: ${id}`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch territory: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Get a territory by SOLID (unique identifier)
   */
  async getTerritoryBySOLID(solid: string): Promise<GeoTerritory> {
    const url = `${API_BASE_URL}/api/geo/territories/solid/${encodeURIComponent(solid)}`;
    console.log(`🔍 Fetching territory by SOLID: ${solid}`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch territory: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Get all territories for an entity/church
   */
  async getTerritoriesByEntity(entityId: string): Promise<{
    entity_id: string;
    territories: GeoTerritory[];
    count: number;
  }> {
    const url = `${API_BASE_URL}/api/geo/territories/entity/${encodeURIComponent(entityId)}`;
    console.log(`⛪ Fetching territories for entity: ${entityId}`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch entity territories: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Search territories by name, address, city, etc.
   */
  async searchTerritories(query: TerritorySearchQuery): Promise<{
    territories: GeoTerritorySimple[];
    count: number;
    limit: number;
    offset: number;
  }> {
    const params = new URLSearchParams();
    if (query.query) params.set('q', query.query);
    if (query.union) params.set('union', query.union);
    if (query.conference) params.set('conference', query.conference);
    if (query.state) params.set('state', query.state);
    if (query.city) params.set('city', query.city);
    params.set('limit', String(query.limit || 50));
    params.set('offset', String(query.offset || 0));

    const url = `${API_BASE_URL}/api/geo/territories/search?${params}`;
    console.log(`🔎 Searching territories: ${query.query || 'all'}`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to search territories: ${response.status}`);
    }

    return response.json();
  }

  /**
   * List territories with filters
   */
  async listTerritories(filters: TerritorySearchQuery): Promise<{
    territories: GeoTerritorySimple[];
    total: number;
    count: number;
    limit: number;
    offset: number;
  }> {
    const params = new URLSearchParams();
    if (filters.union) params.set('union', filters.union);
    if (filters.conference) params.set('conference', filters.conference);
    if (filters.state) params.set('state', filters.state);
    if (filters.city) params.set('city', filters.city);
    params.set('limit', String(filters.limit || 50));
    params.set('offset', String(filters.offset || 0));

    const url = `${API_BASE_URL}/api/geo/territories/list?${params}`;
    console.log(`📋 Listing territories with filters`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to list territories: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Get church locations within bounds
   */
  async getChurchLocations(bounds?: BoundsQuery): Promise<{
    churches: ChurchLocation[];
    count: number;
  }> {
    let url = `${API_BASE_URL}/api/geo/churches`;
    if (bounds) {
      const boundsStr = `${bounds.minLng},${bounds.minLat},${bounds.maxLng},${bounds.maxLat}`;
      url += `?bounds=${boundsStr}`;
    }

    console.log(`⛪ Fetching church locations`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch church locations: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Get a single church by entity ID
   */
  async getChurch(entityId: string): Promise<ChurchLocation> {
    const url = `${API_BASE_URL}/api/geo/churches/${encodeURIComponent(entityId)}`;
    console.log(`⛪ Fetching church: ${entityId}`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch church: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Get statistics for all unions
   */
  async getUnionStats(): Promise<{
    unions: UnionStats[];
    count: number;
  }> {
    const url = `${API_BASE_URL}/api/geo/stats/unions`;
    console.log(`📊 Fetching union stats`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch union stats: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Get statistics for conferences in a union
   */
  async getConferenceStats(unionName: string): Promise<{
    union: string;
    conferences: ConferenceStats[];
    count: number;
  }> {
    const url = `${API_BASE_URL}/api/geo/stats/conferences?union=${encodeURIComponent(unionName)}`;
    console.log(`📊 Fetching conference stats for: ${unionName}`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch conference stats: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Get vector tile URL template
   */
  getVectorTileUrl(): string {
    return `${API_BASE_URL}/api/geo/tiles/{z}/{x}/{y}`;
  }

  /**
   * Get a single vector tile (useful for debugging)
   */
  async getVectorTile(z: number, x: number, y: number): Promise<ArrayBuffer> {
    const url = `${API_BASE_URL}/api/geo/tiles/${z}/${x}/${y}`;
    console.log(`🗺️ Fetching vector tile: z=${z}, x=${x}, y=${y}`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch vector tile: ${response.status}`);
    }

    return response.arrayBuffer();
  }

  /**
   * Convert bounds from map region to BoundsQuery
   */
  regionToBounds(region: {
    latitude: number;
    longitude: number;
    latitudeDelta: number;
    longitudeDelta: number;
  }): BoundsQuery {
    return {
      minLng: region.longitude - region.longitudeDelta / 2,
      minLat: region.latitude - region.latitudeDelta / 2,
      maxLng: region.longitude + region.longitudeDelta / 2,
      maxLat: region.latitude + region.latitudeDelta / 2,
    };
  }

  // ==================== TERRITORY ASSIGNMENT METHODS ====================

  /**
   * Assign a territory to a team/worker
   */
  async assignTerritory(request: CreateAssignmentRequest): Promise<TerritoryAssignment> {
    const url = `${API_BASE_URL}/api/geo/assignments`;
    console.log(`📋 Assigning territory: ${request.territory_id}`);

    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error.error || `Failed to assign territory: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Get a specific assignment by ID
   */
  async getAssignment(assignmentId: string): Promise<TerritoryAssignmentWithDetails> {
    const url = `${API_BASE_URL}/api/geo/assignments/${assignmentId}`;
    console.log(`📋 Fetching assignment: ${assignmentId}`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch assignment: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Get all assignments for a team
   */
  async getTeamAssignments(teamId: string, status?: string): Promise<{
    assignments: TerritoryAssignmentWithDetails[];
    count: number;
  }> {
    const params = new URLSearchParams({ team_id: teamId });
    if (status) params.set('status', status);

    const url = `${API_BASE_URL}/api/geo/assignments?${params}`;
    console.log(`👥 Fetching team assignments: ${teamId}`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch team assignments: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Get all assignments for a worker
   */
  async getWorkerAssignments(workerId: string, status?: string): Promise<{
    assignments: TerritoryAssignmentWithDetails[];
    count: number;
  }> {
    const params = new URLSearchParams({ worker_id: workerId });
    if (status) params.set('status', status);

    const url = `${API_BASE_URL}/api/geo/assignments?${params}`;
    console.log(`👤 Fetching worker assignments: ${workerId}`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch worker assignments: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Get worker's assigned territories as GeoJSON
   */
  async getWorkerTerritoriesGeoJSON(workerId: string): Promise<GeoJSONFeatureCollection> {
    const url = `${API_BASE_URL}/api/geo/assignments/worker/${workerId}/geojson`;
    console.log(`🗺️ Fetching worker territories GeoJSON: ${workerId}`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch worker territories: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Get team's assigned territories as GeoJSON
   */
  async getTeamTerritoriesGeoJSON(teamId: string): Promise<GeoJSONFeatureCollection> {
    const url = `${API_BASE_URL}/api/geo/assignments/team/${teamId}/geojson`;
    console.log(`🗺️ Fetching team territories GeoJSON: ${teamId}`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch team territories: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Update an assignment
   */
  async updateAssignment(assignmentId: string, request: UpdateAssignmentRequest): Promise<void> {
    const url = `${API_BASE_URL}/api/geo/assignments/${assignmentId}`;
    console.log(`✏️ Updating assignment: ${assignmentId}`);

    const response = await fetch(url, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error.error || `Failed to update assignment: ${response.status}`);
    }
  }

  /**
   * Unassign a territory (mark as cancelled)
   */
  async unassignTerritory(assignmentId: string): Promise<void> {
    const url = `${API_BASE_URL}/api/geo/assignments/${assignmentId}`;
    console.log(`❌ Unassigning territory: ${assignmentId}`);

    const response = await fetch(url, {
      method: 'DELETE',
    });

    if (!response.ok) {
      throw new Error(`Failed to unassign territory: ${response.status}`);
    }
  }

  /**
   * Record a visit to a territory (increment visit count)
   */
  async recordTerritoryVisit(assignmentId: string): Promise<void> {
    const url = `${API_BASE_URL}/api/geo/assignments/${assignmentId}/visit`;
    console.log(`📍 Recording territory visit: ${assignmentId}`);

    const response = await fetch(url, { method: 'POST' });

    if (!response.ok) {
      throw new Error(`Failed to record visit: ${response.status}`);
    }
  }

  /**
   * Mark a territory assignment as completed
   */
  async completeAssignment(assignmentId: string, completeness: number = 100): Promise<void> {
    return this.updateAssignment(assignmentId, {
      status: 'completed',
      completeness_percentage: completeness,
    });
  }
}

export const geoTerritoryService = new GeoTerritoryService();
export default geoTerritoryService;
