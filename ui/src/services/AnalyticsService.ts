import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';

// Stub analytics service - uses local storage instead of Firebase
const ANALYTICS_KEY = 'analytics_data';

export interface WorkerAnalytics {
  workerId: string;
  workerName: string;
  totalMinistryHours: number;
  totalDistance: number;
  totalDeliveries: number;
  totalSurveys: number;
  territoriesCovered: number;
  averageSessionDuration: number;
  deliverySuccessRate: number;
  surveyCompletionRate: number;
  lastActivityDate: Date;
  weeklyStats: WeeklyStats;
  monthlyStats: MonthlyStats;
  trends: PerformanceTrends;
}

export interface WeeklyStats {
  hoursThisWeek: number;
  deliveriesThisWeek: number;
  surveysThisWeek: number;
  distanceThisWeek: number;
  daysActive: number;
}

export interface MonthlyStats {
  hoursThisMonth: number;
  deliveriesThisMonth: number;
  surveysThisMonth: number;
  distanceThisMonth: number;
  daysActive: number;
}

export interface PerformanceTrends {
  hoursPerDay: Array<{ date: string; hours: number }>;
  deliveriesPerDay: Array<{ date: string; count: number }>;
  distancePerDay: Array<{ date: string; distance: number }>;
}

export interface TeamAnalytics {
  teamId: string;
  teamName: string;
  totalWorkers: number;
  activeWorkers: number;
  totalMinistryHours: number;
  totalDistance: number;
  totalDeliveries: number;
  averageWorkerPerformance: number;
}

class AnalyticsService {
  private static instance: AnalyticsService;

  static getInstance(): AnalyticsService {
    if (!AnalyticsService.instance) {
      AnalyticsService.instance = new AnalyticsService();
    }
    return AnalyticsService.instance;
  }

  async getWorkerAnalytics(workerId: string, workerName: string = 'Worker'): Promise<WorkerAnalytics> {
    return {
      workerId,
      workerName,
      totalMinistryHours: 0,
      totalDistance: 0,
      totalDeliveries: 0,
      totalSurveys: 0,
      territoriesCovered: 0,
      averageSessionDuration: 0,
      deliverySuccessRate: 0,
      surveyCompletionRate: 0,
      lastActivityDate: new Date(),
      weeklyStats: {
        hoursThisWeek: 0,
        deliveriesThisWeek: 0,
        surveysThisWeek: 0,
        distanceThisWeek: 0,
        daysActive: 0,
      },
      monthlyStats: {
        hoursThisMonth: 0,
        deliveriesThisMonth: 0,
        surveysThisMonth: 0,
        distanceThisMonth: 0,
        daysActive: 0,
      },
      trends: {
        hoursPerDay: [],
        deliveriesPerDay: [],
        distancePerDay: [],
      },
    };
  }

  async getTeamAnalytics(teamId: string): Promise<TeamAnalytics> {
    return {
      teamId,
      teamName: 'Team',
      totalWorkers: 0,
      activeWorkers: 0,
      totalMinistryHours: 0,
      totalDistance: 0,
      totalDeliveries: 0,
      averageWorkerPerformance: 0,
    };
  }

  async getDashboardStats(): Promise<any> {
    return {
      activeWorkers: 0,
      todaySessions: 0,
      todayDeliveries: 0,
      todayDistance: 0,
    };
  }

  listenToWorkerAnalytics(workerId: string, workerName: string, callback: (analytics: WorkerAnalytics) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const analytics = await this.getWorkerAnalytics(workerId, workerName);
      callback(analytics);
    };

    poll();
    intervalId = setInterval(poll, 30000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }

  listenToTeamAnalytics(teamId: string, callback: (analytics: TeamAnalytics) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;



    
    const poll = async () => {
      const analytics = await this.getTeamAnalytics(teamId);
      callback(analytics);
    };

    poll();
    intervalId = setInterval(poll, 30000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }

  async logEvent(eventName: string, data: any): Promise<void> {
    console.log('Analytics event:', eventName, data);
  }
}

export const analyticsService = AnalyticsService.getInstance();
export default AnalyticsService;



