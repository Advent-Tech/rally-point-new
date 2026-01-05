import { authService } from './authService';
import { Platform } from 'react-native';

export type WalkieEvent = {
  type: string;
  team_id: string;
  user_id?: string;
  data?: any;
  timestamp?: string;
};

export interface WalkieWSOptions {
  teamId: string;
  userId: string;
  onOpen?: () => void;
  onClose?: (ev?: any) => void;
  onError?: (err: any) => void;
  onEvent: (evt: WalkieEvent) => void;
}

// WebSocket connects through API Gateway (port 8080)
// API Gateway should proxy /ws/walkie to walkie-service
const getWsBaseUrl = (): string => {
  if (__DEV__) {
    return Platform.select({
      android: 'ws://10.0.2.2:8080',
      ios: 'ws://localhost:8080',
      default: 'ws://localhost:8080',
    })!;
  }
  return 'wss://api.rallypoint.app';
};

export default class WalkieWSClient {
  private ws: WebSocket | null = null;
  private urlBase: string;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 3;
  private reconnectTimeout: any = null;

  constructor() {
    // Use web location for browser, platform-specific URL for native
    if (typeof window !== 'undefined' && window.location && Platform.OS === 'web') {
      const proto = window.location.protocol === 'https:' ? 'wss' : 'ws';
      this.urlBase = `${proto}://${window.location.hostname}:8080`;
    } else {
      this.urlBase = getWsBaseUrl();
    }
    console.log('🔌 WalkieWSClient initialized with URL base:', this.urlBase);
  }

  async connect(opts: WalkieWSOptions): Promise<void> {
    return new Promise(async (resolve, reject) => {
      try {
        const token = await authService.getValidToken();
        const qs = new URLSearchParams();
        if (token) qs.set('token', token);
        qs.set('team_id', opts.teamId);
        qs.set('user_id', opts.userId);

        const url = `${this.urlBase}/ws/walkie?${qs.toString()}`;
        console.log('🔌 Attempting WebSocket connection to:', url);

        // Set a connection timeout
        const connectionTimeout = setTimeout(() => {
          console.log('⚠️ WebSocket connection timeout - proceeding without realtime');
          // Don't reject, just resolve to allow fallback
          resolve();
        }, 5000);

        this.ws = new WebSocket(url);

        this.ws.onopen = () => {
          clearTimeout(connectionTimeout);
          console.log('✅ WebSocket connected successfully');
          this.reconnectAttempts = 0;
          opts.onOpen && opts.onOpen();
          resolve();
        };

        this.ws.onmessage = (ev) => {
          try {
            const data = JSON.parse(ev.data);
            if (data && data.type) {
              console.log('📨 WebSocket message received:', data.type);
              opts.onEvent(data as WalkieEvent);
            }
          } catch (_) {
            // ignore non-JSON
          }
        };

        this.ws.onerror = (err) => {
          clearTimeout(connectionTimeout);
          console.error('❌ WebSocket error:', err);
          opts.onError && opts.onError(err);
          // Don't reject - allow fallback to Firestore
          resolve();
        };

        this.ws.onclose = (ev) => {
          console.log('🔌 WebSocket closed:', ev?.code, ev?.reason);
          opts.onClose && opts.onClose(ev);
        };
      } catch (error) {
        console.error('❌ WebSocket connection setup failed:', error);
        // Don't reject - allow fallback
        resolve();
      }
    });
  }

  isConnected(): boolean {
    return this.ws !== null && this.ws.readyState === WebSocket.OPEN;
  }

  close() {
    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
      this.reconnectTimeout = null;
    }
    try {
      this.ws?.close();
    } catch (_) {}
    this.ws = null;
  }
}
