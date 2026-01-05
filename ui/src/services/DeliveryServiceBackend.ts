import { authService } from './authService';
import { Platform } from 'react-native';

const API_BASE_URL = __DEV__
  ? Platform.select({
      android: 'http://10.0.2.2:8080',
      default: 'http://localhost:8080',
    })!
  : 'https://api.rallypoint.app';

// Types
export interface DeliveryItem {
  id?: string;
  delivery_id?: string;
  item_type: string; // book, magazine, tract, package, other
  item_name: string;
  quantity: number;
  description?: string;
}

export interface Delivery {
  id: string;
  team_id: string;
  worker_id?: string;
  worker_name?: string;
  recipient_name: string;
  recipient_phone?: string;
  recipient_email?: string;
  address: string;
  latitude: number;
  longitude: number;
  delivery_type: string; // literature, package, visit
  priority: string; // low, medium, high, urgent
  status: string; // pending, assigned, in_progress, delivered, failed, cancelled
  notes?: string;
  instructions?: string;
  scheduled_date?: string;
  assigned_at?: string;
  started_at?: string;
  completed_at?: string;
  estimated_time?: number;
  actual_time?: number;
  items?: DeliveryItem[];
  created_at: string;
  updated_at: string;
}

export interface DeliveryStats {
  total_deliveries: number;
  pending_deliveries: number;
  in_progress_deliveries: number;
  completed_deliveries: number;
  failed_deliveries: number;
  completion_rate: number;
  average_delivery_time: number;
  total_routes: number;
  active_routes: number;
}

export interface WorkerDeliveryStats {
  worker_id: string;
  worker_name: string;
  total_deliveries: number;
  completed_deliveries: number;
  failed_deliveries: number;
  completion_rate: number;
  average_delivery_time: number;
  total_distance: number;
  total_routes: number;
}

export interface DeliveryRoute {
  id: string;
  team_id: string;
  worker_id: string;
  worker_name: string;
  route_name: string;
  route_date: string;
  status: string; // planned, active, completed, cancelled
  total_stops: number;
  completed_stops: number;
  estimated_time: number;
  actual_time?: number;
  started_at?: string;
  completed_at?: string;
  deliveries?: Delivery[];
}

export interface CreateDeliveryRequest {
  team_id: string;
  worker_id?: string;
  recipient_name: string;
  recipient_phone?: string;
  recipient_email?: string;
  address: string;
  latitude: number;
  longitude: number;
  delivery_type: string;
  priority: string;
  notes?: string;
  instructions?: string;
  scheduled_date?: string;
  estimated_time?: number;
  items?: Omit<DeliveryItem, 'id' | 'delivery_id'>[];
}

class DeliveryServiceBackendClass {
  private async getAuthToken(): Promise<string | null> {
    try {
      return await authService.getValidToken();
    } catch (error) {
      console.error('❌ Error getting auth token:', error);
      return null;
    }
  }

  private async makeRequest<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${API_BASE_URL}${endpoint}`;
    const token = await this.getAuthToken();

    if (!token) {
      throw new Error('Not authenticated');
    }

    console.log(`📦 Delivery API: ${options.method || 'GET'} ${url}`);

    const response = await fetch(url, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
        ...options.headers,
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ Delivery API Error: ${response.status} - ${errorText}`);

      if (response.status === 401) {
        await authService.clearAuth();
        throw new Error('Authentication required. Please log in again.');
      }

      throw new Error(errorText || `Request failed: ${response.status}`);
    }

    const text = await response.text();
    return text ? JSON.parse(text) : ({} as T);
  }

  // ============ Delivery CRUD ============

  async createDelivery(data: CreateDeliveryRequest): Promise<Delivery> {
    return this.makeRequest<Delivery>('/api/deliveries/', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async getDelivery(id: string): Promise<Delivery> {
    return this.makeRequest<Delivery>(`/api/deliveries/${id}`);
  }

  async updateDelivery(id: string, data: Partial<CreateDeliveryRequest>): Promise<Delivery> {
    return this.makeRequest<Delivery>(`/api/deliveries/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  async deleteDelivery(id: string): Promise<void> {
    await this.makeRequest(`/api/deliveries/${id}`, { method: 'DELETE' });
  }

  // ============ Delivery Status ============

  async updateDeliveryStatus(
    id: string,
    status: string,
    message?: string,
    latitude?: number,
    longitude?: number
  ): Promise<Delivery> {
    return this.makeRequest<Delivery>(`/api/deliveries/${id}/status`, {
      method: 'PUT',
      body: JSON.stringify({ status, message, latitude, longitude }),
    });
  }

  async assignDelivery(id: string, workerId: string): Promise<Delivery> {
    return this.makeRequest<Delivery>(`/api/deliveries/${id}/assign`, {
      method: 'PUT',
      body: JSON.stringify({ worker_id: workerId }),
    });
  }

  async startDelivery(id: string, latitude?: number, longitude?: number): Promise<Delivery> {
    return this.makeRequest<Delivery>(`/api/deliveries/${id}/start`, {
      method: 'PUT',
      body: JSON.stringify({ latitude, longitude }),
    });
  }

  async completeDelivery(
    id: string,
    notes?: string,
    latitude?: number,
    longitude?: number
  ): Promise<Delivery> {
    return this.makeRequest<Delivery>(`/api/deliveries/${id}/complete`, {
      method: 'PUT',
      body: JSON.stringify({ notes, latitude, longitude }),
    });
  }

  // ============ Team Deliveries ============

  async getTeamDeliveries(
    teamId: string,
    status?: string,
    limit: number = 50,
    offset: number = 0
  ): Promise<{ deliveries: Delivery[]; count: number }> {
    let url = `/api/teams/${teamId}/deliveries?limit=${limit}&offset=${offset}`;
    if (status) url += `&status=${status}`;
    return this.makeRequest(url);
  }

  async getTeamStats(teamId: string): Promise<DeliveryStats> {
    return this.makeRequest<DeliveryStats>(`/api/teams/${teamId}/stats`);
  }

  async getTeamWorkerStats(teamId: string): Promise<{ worker_stats: WorkerDeliveryStats[]; count: number }> {
    return this.makeRequest(`/api/teams/${teamId}/worker-stats`);
  }

  // ============ Worker Deliveries ============

  async getWorkerDeliveries(
    workerId: string,
    limit: number = 50,
    offset: number = 0
  ): Promise<{ deliveries: Delivery[]; count: number }> {
    return this.makeRequest(`/api/workers/${workerId}/deliveries?limit=${limit}&offset=${offset}`);
  }

  async getWorkerStats(workerId: string): Promise<WorkerDeliveryStats> {
    return this.makeRequest<WorkerDeliveryStats>(`/api/workers/${workerId}/stats`);
  }

  async getMyDeliveries(limit: number = 50, offset: number = 0): Promise<{ deliveries: Delivery[]; count: number }> {
    const user = await authService.getStoredUser();
    if (!user?.id) throw new Error('User not found');
    return this.getWorkerDeliveries(user.id, limit, offset);
  }

  async getMyStats(): Promise<WorkerDeliveryStats> {
    const user = await authService.getStoredUser();
    if (!user?.id) throw new Error('User not found');
    return this.getWorkerStats(user.id);
  }

  // ============ Routes ============

  async createRoute(data: {
    team_id: string;
    worker_id: string;
    route_name: string;
    route_date: string;
    delivery_ids: string[];
    estimated_time?: number;
  }): Promise<DeliveryRoute> {
    return this.makeRequest<DeliveryRoute>('/api/routes/', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async getRoute(id: string): Promise<DeliveryRoute> {
    return this.makeRequest<DeliveryRoute>(`/api/routes/${id}`);
  }

  async startRoute(id: string): Promise<DeliveryRoute> {
    return this.makeRequest<DeliveryRoute>(`/api/routes/${id}/start`, { method: 'PUT' });
  }

  async completeRoute(id: string): Promise<DeliveryRoute> {
    return this.makeRequest<DeliveryRoute>(`/api/routes/${id}/complete`, { method: 'PUT' });
  }

  async optimizeRoute(id: string): Promise<DeliveryRoute> {
    return this.makeRequest<DeliveryRoute>(`/api/routes/${id}/optimize`, { method: 'PUT' });
  }

  async getTeamRoutes(
    teamId: string,
    limit: number = 50,
    offset: number = 0
  ): Promise<{ routes: DeliveryRoute[]; count: number }> {
    return this.makeRequest(`/api/teams/${teamId}/routes?limit=${limit}&offset=${offset}`);
  }

  async getWorkerRoutes(
    workerId: string,
    limit: number = 50,
    offset: number = 0
  ): Promise<{ routes: DeliveryRoute[]; count: number }> {
    return this.makeRequest(`/api/workers/${workerId}/routes?limit=${limit}&offset=${offset}`);
  }
}

export const DeliveryServiceBackend = new DeliveryServiceBackendClass();
export default DeliveryServiceBackend;
