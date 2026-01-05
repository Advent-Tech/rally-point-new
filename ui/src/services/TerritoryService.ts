import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';
import { authService } from './authService';

export interface Territory {
  id: string;
  name: string;
  coordinates: Array<{lat: number, lng: number}>;
  assignedWorker?: {
    id: string;
    name: string;
    email: string;
  };
  assignedTeam?: {
    teamId: string;
    teamName: string;
  };
  color: string;
  createdAt: number;
  isActive: boolean;
  source?: 'manual' | 'imported';
  originalFileName?: string;
  properties?: Record<string, any>;
}

export interface TerritoryEntry {
  id: string;
  workerId: string;
  workerName: string;
  territoryId: string;
  territoryName: string;
  entryTime: number;
  exitTime?: number;
  location: { lat: number; lng: number };
  isActive: boolean;
}

export interface TerritoryAlert {
  id: string;
  workerId: string;
  workerName: string;
  territoryId: string;
  territoryName: string;
  alertType: 'entry' | 'exit' | 'boundary_violation';
  timestamp: number;
  location: { lat: number; lng: number };
  message: string;
}

const TERRITORIES_KEY = 'territories';
const TERRITORY_STATUS_KEY = 'territoryStatus';

class TerritoryService {
  private workerTerritoryStatus: Map<string, { territoryId: string; isInside: boolean }> = new Map();
  private _cacheAllTerritories: Territory[] | null = null;
  private _cacheTimestamp: number | null = null;
  private _cacheTTLms = 60 * 1000;

  private getApiBase(): string {
    if (Platform.OS === 'android') return 'http://10.0.2.2:8080';
    if (typeof window !== 'undefined' && window.location) {
      return `${window.location.protocol}//${window.location.hostname}:8080`;
    }
    return 'http://localhost:8080';
  }

  async createTerritory(territory: Omit<Territory, 'id'>): Promise<string> {
    try {
      const id = `territory_${Date.now()}`;
      const newTerritory: Territory = {
        ...territory,
        id,
        createdAt: Date.now(),
        isActive: true,
      };

      const territories = await this.getAllTerritories();
      territories.push(newTerritory);
      await AsyncStorage.setItem(TERRITORIES_KEY, JSON.stringify(territories));

      console.log('✅ Territory created:', id);
      return id;
    } catch (error) {
      console.error('❌ Error creating territory:', error);
      throw error;
    }
  }

  async updateTerritory(territoryId: string, updates: Partial<Territory>): Promise<void> {
    try {
      const territories = await this.getAllTerritories();
      const index = territories.findIndex(t => t.id === territoryId);
      if (index !== -1) {
        territories[index] = { ...territories[index], ...updates };
        await AsyncStorage.setItem(TERRITORIES_KEY, JSON.stringify(territories));
        this._cacheAllTerritories = null;
      }
      console.log('✅ Territory updated:', territoryId);
    } catch (error) {
      console.error('❌ Error updating territory:', error);
      throw error;
    }
  }

  async deleteTerritory(territoryId: string): Promise<void> {
    try {
      const territories = await this.getAllTerritories();
      const filtered = territories.filter(t => t.id !== territoryId);
      await AsyncStorage.setItem(TERRITORIES_KEY, JSON.stringify(filtered));
      this._cacheAllTerritories = null;
      console.log('✅ Territory deleted:', territoryId);
    } catch (error) {
      console.error('❌ Error deleting territory:', error);
      throw error;
    }
  }

  async getAllTerritories(): Promise<Territory[]> {
    try {
      const data = await AsyncStorage.getItem(TERRITORIES_KEY);
      return data ? JSON.parse(data) : [];
    } catch (error) {
      console.error('❌ Error fetching territories:', error);
      return [];
    }
  }

  async getAllTerritoriesCached(forceRefresh = false): Promise<Territory[]> {
    const now = Date.now();
    if (!forceRefresh && this._cacheAllTerritories && this._cacheTimestamp &&
        (now - this._cacheTimestamp < this._cacheTTLms)) {
      return this._cacheAllTerritories;
    }
    const data = await this.getAllTerritories();
    this._cacheAllTerritories = data;
    this._cacheTimestamp = now;
    return data;
  }

  getUniqueUnions(territories: Territory[]): string[] {
    const set = new Set<string>();
    territories.forEach(t => {
      const u = t.properties?.Union || t.properties?.union || t.properties?.UNION;
      if (u) set.add(String(u));
    });
    return Array.from(set).sort();
  }

  getConferencesByUnion(territories: Territory[], union?: string): string[] {
    const set = new Set<string>();
    territories.forEach(t => {
      const u = t.properties?.Union || t.properties?.union || t.properties?.UNION;
      const c = t.properties?.Conference || t.properties?.conference || t.properties?.CONFERENCE;
      if ((!union || u === union) && c) set.add(String(c));
    });
    return Array.from(set).sort();
  }

  getChurchesByUnionConference(territories: Territory[], union?: string, conference?: string): string[] {
    const set = new Set<string>();
    territories.forEach(t => {
      const u = t.properties?.Union || t.properties?.union || t.properties?.UNION;
      const c = t.properties?.Conference || t.properties?.conference || t.properties?.CONFERENCE;
      const e = t.properties?.Entity || t.properties?.entity || t.properties?.CHURCH || t.properties?.Church;
      if ((!union || u === union) && (!conference || c === conference) && e) set.add(String(e));
    });
    return Array.from(set).sort();
  }

  filterTerritories(
    territories: Territory[],
    opts: { union?: string; conference?: string; church?: string; search?: string }
  ): Territory[] {
    const lower = opts.search?.toLowerCase();
    return territories.filter(t => {
      const props = t.properties || {} as any;
      const u = props.Union || props.union || props.UNION;
      const c = props.Conference || props.conference || props.CONFERENCE;
      const e = props.Entity || props.entity || props.CHURCH || props.Church;
      const street = props['Street Add'] || props.street || props.address || props['Street'];
      const zip = props.Zipcode || props.ZIP || props.zip || props.postcode;

      if (opts.union && u !== opts.union) return false;
      if (opts.conference && c !== opts.conference) return false;
      if (opts.church && e !== opts.church) return false;

      if (lower) {
        const matches =
          (e && String(e).toLowerCase().includes(lower)) ||
          (street && String(street).toLowerCase().includes(lower)) ||
          (zip && String(zip).toLowerCase().includes(lower));
        if (!matches) return false;
      }
      return true;
    });
  }

  async getWorkerTerritory(workerId: string): Promise<Territory | null> {
    const territories = await this.getAllTerritories();
    return territories.find(t => t.assignedWorker?.id === workerId && t.isActive) || null;
  }

  async getWorkerTerritoriesByEmail(email: string): Promise<Territory[]> {
    const territories = await this.getAllTerritories();
    return territories.filter(t => t.assignedWorker?.email === email && t.isActive);
  }

  async assignTerritoryToWorker(
    territoryId: string,
    worker: { id: string; name: string; email: string }
  ): Promise<void> {
    await this.updateTerritory(territoryId, { assignedWorker: worker });
    console.log('✅ Territory assigned:', territoryId, 'to', worker.name);
  }

  async unassignTerritory(territoryId: string): Promise<void> {
    await this.updateTerritory(territoryId, { assignedWorker: undefined });
    console.log('✅ Territory unassigned:', territoryId);
  }

  async assignTerritoryToTeam(
    territoryId: string,
    team: { teamId: string; teamName: string }
  ): Promise<void> {
    await this.updateTerritory(territoryId, { assignedTeam: team });
    console.log('✅ Territory assigned to team:', territoryId);
  }

  async unassignTerritoryFromTeam(territoryId: string): Promise<void> {
    await this.updateTerritory(territoryId, { assignedTeam: undefined });
    console.log('✅ Territory unassigned from team:', territoryId);
  }

  async getTeamTerritories(teamId: string): Promise<Territory[]> {
    const territories = await this.getAllTerritories();
    return territories.filter(t => t.assignedTeam?.teamId === teamId && t.isActive);
  }

  async getWorkerTerritoriesWithTeam(workerId: string, teamId?: string): Promise<Territory[]> {
    const territories: Territory[] = [];
    const all = await this.getAllTerritories();

    all.forEach(t => {
      if (t.assignedWorker?.id === workerId && t.isActive) {
        territories.push(t);
      }
    });

    if (teamId) {
      const teamTerritories = await this.getTeamTerritories(teamId);
      territories.push(...teamTerritories);
    }

    return territories;
  }

  isPointInTerritory(point: { lat: number; lng: number }, territory: Territory): boolean {
    const polygon = territory.coordinates;
    const x = point.lat;
    const y = point.lng;
    let inside = false;

    for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      const xi = polygon[i].lat;
      const yi = polygon[i].lng;
      const xj = polygon[j].lat;
      const yj = polygon[j].lng;

      if (((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }

    return inside;
  }

  async trackWorkerInTerritory(
    workerId: string,
    workerName: string,
    location: { lat: number; lng: number }
  ): Promise<void> {
    try {
      const territory = await this.getWorkerTerritory(workerId);
      if (!territory) return;

      const isInside = this.isPointInTerritory(location, territory);
      this.workerTerritoryStatus.set(workerId, { territoryId: territory.id, isInside });

      // Store status locally
      const statusData = {
        territoryId: territory.id,
        territoryName: territory.name,
        isInside,
        lastUpdate: Date.now(),
        location
      };
      await AsyncStorage.setItem(`${TERRITORY_STATUS_KEY}_${workerId}`, JSON.stringify(statusData));
    } catch (error) {
      console.error('❌ Error tracking worker in territory:', error);
    }
  }

  listenToTerritoryAlerts(callback: (alerts: TerritoryAlert[]) => void): () => void {
    // Poll-based implementation
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      try {
        const data = await AsyncStorage.getItem('territoryAlerts');
        const alerts: TerritoryAlert[] = data ? JSON.parse(data) : [];
        alerts.sort((a, b) => b.timestamp - a.timestamp);
        callback(alerts);
      } catch (error) {
        callback([]);
      }
    };

    poll();
    intervalId = setInterval(poll, 5000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }

  listenToWorkerTerritoryStatus(workerId: string, callback: (status: any) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      try {
        const data = await AsyncStorage.getItem(`${TERRITORY_STATUS_KEY}_${workerId}`);
        callback(data ? JSON.parse(data) : null);
      } catch (error) {
        callback(null);
      }
    };

    poll();
    intervalId = setInterval(poll, 3000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }

  cleanup(): void {
    this.workerTerritoryStatus.clear();
  }
}

export const territoryService = new TerritoryService();
export default territoryService;
