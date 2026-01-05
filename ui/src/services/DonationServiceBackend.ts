import { authService } from './authService';
import { Platform } from 'react-native';

const API_BASE_URL = __DEV__
  ? Platform.select({
      android: 'http://10.0.2.2:8080',
      default: 'http://localhost:8080',
    })!
  : 'https://api.rallypoint.app';

// Types
export interface Donation {
  id: string;
  team_id: string;
  worker_id: string;
  worker_name: string;
  donor_name: string;
  donor_email?: string;
  donor_phone?: string;
  amount: number;
  currency: string;
  payment_method: string; // cash, card, check, online
  donation_type: string; // one_time, recurring, pledge
  purpose?: string;
  notes?: string;
  latitude?: number;
  longitude?: number;
  delivery_id?: string;
  receipt_number?: string;
  donated_at: string;
  created_at: string;
  updated_at: string;
}

export interface DonationStats {
  total_donations: number;
  total_amount: number;
  today_donations: number;
  today_amount: number;
  week_donations: number;
  week_amount: number;
  month_donations: number;
  month_amount: number;
  average_donation: number;
  largest_donation: number;
  unique_donors: number;
  cash_amount: number;
  card_amount: number;
  check_amount: number;
  online_amount: number;
}

export interface WorkerDonationStats {
  worker_id: string;
  worker_name: string;
  total_donations: number;
  total_amount: number;
  average_donation: number;
  unique_donors: number;
}

export interface CreateDonationRequest {
  team_id: string;
  donor_name: string;
  donor_email?: string;
  donor_phone?: string;
  amount: number;
  currency?: string;
  payment_method: string;
  donation_type?: string;
  purpose?: string;
  notes?: string;
  latitude?: number;
  longitude?: number;
  delivery_id?: string;
}

class DonationServiceBackendClass {
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

    console.log(`💰 Donation API: ${options.method || 'GET'} ${url}`);

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
      console.error(`❌ Donation API Error: ${response.status} - ${errorText}`);

      if (response.status === 401) {
        await authService.clearAuth();
        throw new Error('Authentication required. Please log in again.');
      }

      // Return default for 404 on stats endpoints
      if (response.status === 404 && endpoint.includes('/stats')) {
        return this.getDefaultStats() as T;
      }

      throw new Error(errorText || `Request failed: ${response.status}`);
    }

    const text = await response.text();
    return text ? JSON.parse(text) : ({} as T);
  }

  private getDefaultStats(): DonationStats {
    return {
      total_donations: 0,
      total_amount: 0,
      today_donations: 0,
      today_amount: 0,
      week_donations: 0,
      week_amount: 0,
      month_donations: 0,
      month_amount: 0,
      average_donation: 0,
      largest_donation: 0,
      unique_donors: 0,
      cash_amount: 0,
      card_amount: 0,
      check_amount: 0,
      online_amount: 0,
    };
  }

  // ============ Donation CRUD ============

  async createDonation(data: CreateDonationRequest): Promise<Donation> {
    return this.makeRequest<Donation>('/api/donations/', {
      method: 'POST',
      body: JSON.stringify({
        ...data,
        currency: data.currency || 'USD',
        donation_type: data.donation_type || 'one_time',
      }),
    });
  }

  async getDonation(id: string): Promise<Donation> {
    return this.makeRequest<Donation>(`/api/donations/${id}`);
  }

  async updateDonation(id: string, data: Partial<CreateDonationRequest>): Promise<Donation> {
    return this.makeRequest<Donation>(`/api/donations/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  async deleteDonation(id: string): Promise<void> {
    await this.makeRequest(`/api/donations/${id}`, { method: 'DELETE' });
  }

  // ============ List Donations ============

  async listDonations(filters?: {
    team_id?: string;
    worker_id?: string;
    start_date?: string;
    end_date?: string;
    payment_method?: string;
    min_amount?: number;
    max_amount?: number;
    limit?: number;
    offset?: number;
  }): Promise<{ donations: Donation[]; count: number }> {
    const params = new URLSearchParams();
    if (filters) {
      Object.entries(filters).forEach(([key, value]) => {
        if (value !== undefined) params.append(key, String(value));
      });
    }
    const query = params.toString() ? `?${params.toString()}` : '';
    return this.makeRequest(`/api/donations${query}`);
  }

  // ============ Worker Donations ============

  async getWorkerDonations(
    workerId: string,
    limit: number = 50,
    offset: number = 0
  ): Promise<{ donations: Donation[]; count: number }> {
    return this.makeRequest(`/api/workers/${workerId}/donations?limit=${limit}&offset=${offset}`);
  }

  async getWorkerStats(workerId: string, days: number = 30): Promise<DonationStats> {
    try {
      return await this.makeRequest<DonationStats>(`/api/workers/${workerId}/donation-stats?days=${days}`);
    } catch (error) {
      console.warn('Worker donation stats not available:', error);
      return this.getDefaultStats();
    }
  }

  async getMyDonations(limit: number = 50, offset: number = 0): Promise<{ donations: Donation[]; count: number }> {
    const user = await authService.getStoredUser();
    if (!user?.id) throw new Error('User not found');
    return this.getWorkerDonations(user.id, limit, offset);
  }

  async getMyStats(days: number = 30): Promise<DonationStats> {
    try {
      return await this.makeRequest<DonationStats>(`/api/donations/my-stats?days=${days}`);
    } catch (error) {
      // Fallback to getting stats via user ID
      const user = await authService.getStoredUser();
      if (!user?.id) return this.getDefaultStats();
      return this.getWorkerStats(user.id, days);
    }
  }

  // ============ Team Donations ============

  async getTeamDonations(
    teamId: string,
    limit: number = 50,
    offset: number = 0
  ): Promise<{ donations: Donation[]; count: number }> {
    return this.makeRequest(`/api/teams/${teamId}/donations?limit=${limit}&offset=${offset}`);
  }

  async getTeamStats(teamId: string, days: number = 30): Promise<DonationStats> {
    try {
      return await this.makeRequest<DonationStats>(`/api/teams/${teamId}/donation-stats?days=${days}`);
    } catch (error) {
      console.warn('Team donation stats not available:', error);
      return this.getDefaultStats();
    }
  }

  async getTeamWorkerStats(teamId: string): Promise<{ worker_stats: WorkerDonationStats[]; count: number }> {
    try {
      return await this.makeRequest(`/api/teams/${teamId}/donation-worker-stats`);
    } catch (error) {
      console.warn('Team worker donation stats not available:', error);
      return { worker_stats: [], count: 0 };
    }
  }

  // ============ Quick Record (Simplified) ============

  async recordDonation(
    donorName: string,
    amount: number,
    paymentMethod: string = 'cash',
    teamId: string,
    notes?: string,
    latitude?: number,
    longitude?: number
  ): Promise<Donation> {
    return this.createDonation({
      team_id: teamId,
      donor_name: donorName,
      amount,
      payment_method: paymentMethod,
      notes,
      latitude,
      longitude,
    });
  }
}

export const DonationServiceBackend = new DonationServiceBackendClass();
export default DonationServiceBackend;
