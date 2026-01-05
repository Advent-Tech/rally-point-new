import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';

export interface BookAssignment {
  id: string;
  workerId?: string;
  workerName?: string;
  workerEmail?: string;
  teamId?: string;
  teamName?: string;
  bookTitle: string;
  bookType: 'bible' | 'tract' | 'magazine' | 'study_guide';
  quantity: number;
  assignedBy: {
    uid: string;
    name: string;
    email: string;
  };
  assignedAt: number;
  dueDate?: number;
  completedAt?: number;
  status: 'assigned' | 'in_progress' | 'completed' | 'cancelled';
  notes?: string;
  deliveredCount: number;
  returnedCount: number;
}

const ASSIGNMENTS_KEY = 'book_assignments';

export class BookAssignmentService {
  static async createAssignment(assignment: Omit<BookAssignment, 'id' | 'assignedAt' | 'status' | 'deliveredCount' | 'returnedCount'>): Promise<string> {
    try {
      const id = `assignment_${Date.now()}`;
      const newAssignment: BookAssignment = {
        ...assignment,
        id,
        assignedAt: Date.now(),
        status: 'assigned',
        deliveredCount: 0,
        returnedCount: 0,
      };

      const data = await AsyncStorage.getItem(ASSIGNMENTS_KEY);
      const assignments: BookAssignment[] = data ? JSON.parse(data) : [];
      assignments.push(newAssignment);
      await AsyncStorage.setItem(ASSIGNMENTS_KEY, JSON.stringify(assignments));

      return id;
    } catch (error) {
      console.error('Error creating assignment:', error);
      throw error;
    }
  }

  static async updateAssignment(assignmentId: string, updates: Partial<BookAssignment>): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(ASSIGNMENTS_KEY);
      const assignments: BookAssignment[] = data ? JSON.parse(data) : [];
      const index = assignments.findIndex(a => a.id === assignmentId);

      if (index !== -1) {
        assignments[index] = { ...assignments[index], ...updates };
        await AsyncStorage.setItem(ASSIGNMENTS_KEY, JSON.stringify(assignments));
      }
    } catch (error) {
      console.error('Error updating assignment:', error);
      throw error;
    }
  }

  static async deleteAssignment(assignmentId: string): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(ASSIGNMENTS_KEY);
      const assignments: BookAssignment[] = data ? JSON.parse(data) : [];
      const filtered = assignments.filter(a => a.id !== assignmentId);
      await AsyncStorage.setItem(ASSIGNMENTS_KEY, JSON.stringify(filtered));
    } catch (error) {
      console.error('Error deleting assignment:', error);
      throw error;
    }
  }

  static async getAllAssignments(): Promise<BookAssignment[]> {
    try {
      const data = await AsyncStorage.getItem(ASSIGNMENTS_KEY);
      return data ? JSON.parse(data) : [];
    } catch (error) {
      console.error('Error getting assignments:', error);
      return [];
    }
  }

  static async getAssignmentById(assignmentId: string): Promise<BookAssignment | null> {
    try {
      const assignments = await this.getAllAssignments();
      return assignments.find(a => a.id === assignmentId) || null;
    } catch (error) {
      console.error('Error getting assignment:', error);
      return null;
    }
  }

  static async getWorkerAssignments(workerId: string): Promise<BookAssignment[]> {
    try {
      const assignments = await this.getAllAssignments();
      return assignments.filter(a => a.workerId === workerId);
    } catch (error) {
      console.error('Error getting worker assignments:', error);
      return [];
    }
  }

  static async getTeamAssignments(teamId: string): Promise<BookAssignment[]> {
    try {
      const assignments = await this.getAllAssignments();
      return assignments.filter(a => a.teamId === teamId);
    } catch (error) {
      console.error('Error getting team assignments:', error);
      return [];
    }
  }

  static async recordDelivery(assignmentId: string, count: number): Promise<void> {
    try {
      const assignment = await this.getAssignmentById(assignmentId);
      if (assignment) {
        const newDeliveredCount = assignment.deliveredCount + count;
        const status = newDeliveredCount >= assignment.quantity ? 'completed' : 'in_progress';
        await this.updateAssignment(assignmentId, {
          deliveredCount: newDeliveredCount,
          status,
          completedAt: status === 'completed' ? Date.now() : undefined,
        });
      }
    } catch (error) {
      console.error('Error recording delivery:', error);
      throw error;
    }
  }

  static async recordReturn(assignmentId: string, count: number): Promise<void> {
    try {
      const assignment = await this.getAssignmentById(assignmentId);
      if (assignment) {
        await this.updateAssignment(assignmentId, {
          returnedCount: assignment.returnedCount + count,
        });
      }
    } catch (error) {
      console.error('Error recording return:', error);
      throw error;
    }
  }

  static listenToWorkerAssignments(workerId: string, callback: (assignments: BookAssignment[]) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const assignments = await this.getWorkerAssignments(workerId);
      callback(assignments);
    };

    poll();
    intervalId = setInterval(poll, 5000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }
}

export default BookAssignmentService;
