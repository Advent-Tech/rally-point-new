import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';

export interface Book {
  id: string;
  title: string;
  author?: string;
  isbn?: string;
  category: 'bible' | 'tract' | 'magazine' | 'study_guide' | 'book' | 'other';
  description?: string;
  language: string;
  price?: number;
  stockQuantity: number;
  lowStockThreshold: number;
  imageUrl?: string;
  barcode?: string;
  isActive: boolean;
  createdAt: number;
  updatedAt: number;
}

const BOOKS_KEY = 'books';

export class BookService {
  static async createBook(book: Omit<Book, 'id' | 'createdAt' | 'updatedAt'>): Promise<string> {
    try {
      const id = `book_${Date.now()}`;
      const now = Date.now();
      const newBook: Book = {
        ...book,
        id,
        createdAt: now,
        updatedAt: now,
      };

      const data = await AsyncStorage.getItem(BOOKS_KEY);
      const books: Book[] = data ? JSON.parse(data) : [];
      books.push(newBook);
      await AsyncStorage.setItem(BOOKS_KEY, JSON.stringify(books));

      return id;
    } catch (error) {
      console.error('Error creating book:', error);
      throw error;
    }
  }

  static async updateBook(bookId: string, updates: Partial<Book>): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(BOOKS_KEY);
      const books: Book[] = data ? JSON.parse(data) : [];
      const index = books.findIndex(b => b.id === bookId);

      if (index !== -1) {
        books[index] = { ...books[index], ...updates, updatedAt: Date.now() };
        await AsyncStorage.setItem(BOOKS_KEY, JSON.stringify(books));
      }
    } catch (error) {
      console.error('Error updating book:', error);
      throw error;
    }
  }

  static async deleteBook(bookId: string): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(BOOKS_KEY);
      const books: Book[] = data ? JSON.parse(data) : [];
      const filtered = books.filter(b => b.id !== bookId);
      await AsyncStorage.setItem(BOOKS_KEY, JSON.stringify(filtered));
    } catch (error) {
      console.error('Error deleting book:', error);
      throw error;
    }
  }

  static async getAllBooks(): Promise<Book[]> {
    try {
      const data = await AsyncStorage.getItem(BOOKS_KEY);
      return data ? JSON.parse(data) : [];
    } catch (error) {
      console.error('Error getting books:', error);
      return [];
    }
  }

  static async getBookById(bookId: string): Promise<Book | null> {
    try {
      const books = await this.getAllBooks();
      return books.find(b => b.id === bookId) || null;
    } catch (error) {
      console.error('Error getting book:', error);
      return null;
    }
  }

  static async getBooksByCategory(category: string): Promise<Book[]> {
    try {
      const books = await this.getAllBooks();
      return books.filter(b => b.category === category && b.isActive);
    } catch (error) {
      console.error('Error getting books by category:', error);
      return [];
    }
  }

  static async getLowStockBooks(): Promise<Book[]> {
    try {
      const books = await this.getAllBooks();
      return books.filter(b => b.stockQuantity <= b.lowStockThreshold && b.isActive);
    } catch (error) {
      console.error('Error getting low stock books:', error);
      return [];
    }
  }

  static async updateStock(bookId: string, quantity: number): Promise<void> {
    try {
      const book = await this.getBookById(bookId);
      if (book) {
        await this.updateBook(bookId, { stockQuantity: book.stockQuantity + quantity });
      }
    } catch (error) {
      console.error('Error updating stock:', error);
      throw error;
    }
  }

  static listenToBooks(callback: (books: Book[]) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const books = await this.getAllBooks();
      callback(books);
    };

    poll();
    intervalId = setInterval(poll, 10000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }
}

export default BookService;
