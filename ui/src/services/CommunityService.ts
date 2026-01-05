import AsyncStorage from '@react-native-async-storage/async-storage';

// Types for Community features
export interface NewsItem {
  id: string;
  title: string;
  content: string;
  author: string;
  authorId: string;
  timestamp: Date;
  likes: number;
  comments: number;
  image?: string;
  category: 'announcement' | 'testimony' | 'prayer_request' | 'general';
  isActive: boolean;
}

export interface Comment {
  id: string;
  postId: string;
  authorId: string;
  authorName: string;
  content: string;
  timestamp: Date;
}

export interface PrayerRequest {
  id: string;
  authorId: string;
  authorName: string;
  content: string;
  timestamp: Date;
  prayerCount: number;
  isActive: boolean;
}

const NEWS_KEY = 'community_news';
const COMMENTS_KEY = 'community_comments';
const PRAYERS_KEY = 'community_prayers';

export class CommunityService {
  static async createNewsItem(item: Omit<NewsItem, 'id' | 'timestamp' | 'likes' | 'comments'>): Promise<string> {
    try {
      const id = `news_${Date.now()}`;
      const newItem: NewsItem = {
        ...item,
        id,
        timestamp: new Date(),
        likes: 0,
        comments: 0,
      };

      const data = await AsyncStorage.getItem(NEWS_KEY);
      const items: NewsItem[] = data ? JSON.parse(data) : [];
      items.push(newItem);
      await AsyncStorage.setItem(NEWS_KEY, JSON.stringify(items));

      return id;
    } catch (error) {
      console.error('Error creating news item:', error);
      throw error;
    }
  }

  static async getAllNews(): Promise<NewsItem[]> {
    try {
      const data = await AsyncStorage.getItem(NEWS_KEY);
      const items: NewsItem[] = data ? JSON.parse(data) : [];
      return items.filter(i => i.isActive).sort((a, b) =>
        new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
      );
    } catch (error) {
      console.error('Error getting news:', error);
      return [];
    }
  }

  static async likeNews(newsId: string): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(NEWS_KEY);
      const items: NewsItem[] = data ? JSON.parse(data) : [];
      const index = items.findIndex(i => i.id === newsId);
      if (index !== -1) {
        items[index].likes++;
        await AsyncStorage.setItem(NEWS_KEY, JSON.stringify(items));
      }
    } catch (error) {
      console.error('Error liking news:', error);
    }
  }

  static async addComment(postId: string, authorId: string, authorName: string, content: string): Promise<string> {
    try {
      const id = `comment_${Date.now()}`;
      const comment: Comment = {
        id,
        postId,
        authorId,
        authorName,
        content,
        timestamp: new Date(),
      };

      const data = await AsyncStorage.getItem(COMMENTS_KEY);
      const comments: Comment[] = data ? JSON.parse(data) : [];
      comments.push(comment);
      await AsyncStorage.setItem(COMMENTS_KEY, JSON.stringify(comments));

      // Update comment count
      const newsData = await AsyncStorage.getItem(NEWS_KEY);
      const items: NewsItem[] = newsData ? JSON.parse(newsData) : [];
      const index = items.findIndex(i => i.id === postId);
      if (index !== -1) {
        items[index].comments++;
        await AsyncStorage.setItem(NEWS_KEY, JSON.stringify(items));
      }

      return id;
    } catch (error) {
      console.error('Error adding comment:', error);
      throw error;
    }
  }

  static async getComments(postId: string): Promise<Comment[]> {
    try {
      const data = await AsyncStorage.getItem(COMMENTS_KEY);
      const comments: Comment[] = data ? JSON.parse(data) : [];
      return comments.filter(c => c.postId === postId);
    } catch (error) {
      console.error('Error getting comments:', error);
      return [];
    }
  }

  static async createPrayerRequest(authorId: string, authorName: string, content: string): Promise<string> {
    try {
      const id = `prayer_${Date.now()}`;
      const request: PrayerRequest = {
        id,
        authorId,
        authorName,
        content,
        timestamp: new Date(),
        prayerCount: 0,
        isActive: true,
      };

      const data = await AsyncStorage.getItem(PRAYERS_KEY);
      const requests: PrayerRequest[] = data ? JSON.parse(data) : [];
      requests.push(request);
      await AsyncStorage.setItem(PRAYERS_KEY, JSON.stringify(requests));

      return id;
    } catch (error) {
      console.error('Error creating prayer request:', error);
      throw error;
    }
  }

  static async getPrayerRequests(): Promise<PrayerRequest[]> {
    try {
      const data = await AsyncStorage.getItem(PRAYERS_KEY);
      const requests: PrayerRequest[] = data ? JSON.parse(data) : [];
      return requests.filter(r => r.isActive);
    } catch (error) {
      console.error('Error getting prayer requests:', error);
      return [];
    }
  }

  static async prayForRequest(requestId: string): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(PRAYERS_KEY);
      const requests: PrayerRequest[] = data ? JSON.parse(data) : [];
      const index = requests.findIndex(r => r.id === requestId);
      if (index !== -1) {
        requests[index].prayerCount++;
        await AsyncStorage.setItem(PRAYERS_KEY, JSON.stringify(requests));
      }
    } catch (error) {
      console.error('Error praying for request:', error);
    }
  }

  static listenToNews(callback: (news: NewsItem[]) => void): () => void {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async () => {
      const news = await this.getAllNews();
      callback(news);
    };

    poll();
    intervalId = setInterval(poll, 10000);

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }
}

export default CommunityService;
