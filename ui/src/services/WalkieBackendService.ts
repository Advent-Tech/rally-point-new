import { authService } from './authService';
import { Platform } from 'react-native';

// All requests go through the API Gateway (port 8080)
// API Gateway proxies to walkie-service internally
const API_BASE = __DEV__
  ? Platform.select({
      android: 'http://10.0.2.2:8080',
      default: 'http://localhost:8080',
    })!
  : 'https://api.rallypoint.app';

async function authorizedFetch(pathOrUrl: string, init: RequestInit = {}) {
  // Use getValidToken() which auto-refreshes expired tokens
  const token = await authService.getValidToken();
  if (!token) {
    throw new Error('Not authenticated - please log in again');
  }

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(init.headers as Record<string, string>),
  };
  headers.Authorization = `Bearer ${token}`;

  const url = pathOrUrl.startsWith('http') ? pathOrUrl : `${API_BASE}${pathOrUrl}`;
  const resp = await fetch(url, { ...init, headers });

  if (!resp.ok) {
    const text = await resp.text();
    // If we get 401 even after refresh, session is invalid
    if (resp.status === 401) {
      throw new Error('Session expired - please log in again');
    }
    throw new Error(text || `HTTP ${resp.status}`);
  }

  const text = await resp.text();
  return text ? JSON.parse(text) : {};
}

export interface StartTransmissionResponse {
  id: string;
  team_id: string;
  speaker_id: string;
  speaker_name: string;
  is_active: boolean;
  started_at: string;
}

export const WalkieBackendService = {
  async startTransmission(teamId: string, speakerName: string): Promise<StartTransmissionResponse> {
    return authorizedFetch('/api/walkie/start', {
      method: 'POST',
      body: JSON.stringify({ team_id: teamId, speaker_name: speakerName }),
    });
  },

  async endTransmission(sessionId: string, audioUrl?: string, duration?: number): Promise<any> {
    return authorizedFetch('/api/walkie/end', {
      method: 'POST',
      body: JSON.stringify({ session_id: sessionId, audio_url: audioUrl, duration }),
    });
  },

  async getActiveSession(teamId: string): Promise<StartTransmissionResponse | null> {
    try {
      return authorizedFetch(`/api/walkie/teams/${teamId}/session`);
    } catch (e: any) {
      if (String(e.message || '').includes('404')) return null;
      throw e;
    }
  },

  async getTeamState(teamId: string): Promise<any> {
    return authorizedFetch(`/api/walkie/teams/${teamId}/state`);
  },

  async getTeamMessages(teamId: string, limit = 50, offset = 0): Promise<{ messages: any[]; count: number }> {
    return authorizedFetch(`/api/walkie/messages/team/${teamId}?limit=${limit}&offset=${offset}`);
  },

  async sendMessage(teamId: string, message: string, messageType: 'text' | 'audio' = 'text'): Promise<any> {
    return authorizedFetch('/api/walkie/messages', {
      method: 'POST',
      body: JSON.stringify({ team_id: teamId, message, message_type: messageType }),
    });
  },
};
export default WalkieBackendService;
