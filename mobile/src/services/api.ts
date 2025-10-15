import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { PaymentStream, StreamCreationParams, StreamBalance } from '../types';

const API_BASE_URL = 'http://localhost:3000/api'; // Configure for your environment

class ApiService {
  private baseURL: string;
  private authToken: string | null = null;

  constructor(baseURL: string = API_BASE_URL) {
    this.baseURL = baseURL;
    this.loadAuthToken();
  }

  private async loadAuthToken() {
    try {
      this.authToken = await AsyncStorage.getItem('auth_token');
    } catch (error) {
      console.error('Failed to load auth token:', error);
    }
  }

  private getHeaders() {
    const headers: any = {
      'Content-Type': 'application/json',
    };
    
    if (this.authToken) {
      headers.Authorization = `Bearer ${this.authToken}`;
    }
    
    return headers;
  }

  async authenticate(walletAddress: string): Promise<string> {
    try {
      const response = await axios.post(`${this.baseURL}/auth/login`, {
        walletAddress,
      });
      
      this.authToken = response.data.token;
      await AsyncStorage.setItem('auth_token', this.authToken!);
      
      return this.authToken!;
    } catch (error) {
      console.error('Authentication failed:', error);
      throw error;
    }
  }

  async getStreams(): Promise<PaymentStream[]> {
    try {
      const response = await axios.get(`${this.baseURL}/streams`, {
        headers: this.getHeaders(),
      });
      return response.data;
    } catch (error) {
      console.error('Failed to fetch streams:', error);
      throw error;
    }
  }

  async getStream(streamId: string): Promise<PaymentStream> {
    try {
      const response = await axios.get(`${this.baseURL}/streams/${streamId}`, {
        headers: this.getHeaders(),
      });
      return response.data;
    } catch (error) {
      console.error('Failed to fetch stream:', error);
      throw error;
    }
  }

  async createStream(params: StreamCreationParams): Promise<PaymentStream> {
    try {
      const response = await axios.post(`${this.baseURL}/streams`, params, {
        headers: this.getHeaders(),
      });
      return response.data;
    } catch (error) {
      console.error('Failed to create stream:', error);
      throw error;
    }
  }

  async cancelStream(streamId: string): Promise<boolean> {
    try {
      const response = await axios.delete(`${this.baseURL}/streams/${streamId}`, {
        headers: this.getHeaders(),
      });
      return response.data.success;
    } catch (error) {
      console.error('Failed to cancel stream:', error);
      throw error;
    }
  }

  async withdrawFromStream(streamId: string): Promise<number> {
    try {
      const response = await axios.post(`${this.baseURL}/streams/${streamId}/withdraw`, {}, {
        headers: this.getHeaders(),
      });
      return response.data.amount;
    } catch (error) {
      console.error('Failed to withdraw from stream:', error);
      throw error;
    }
  }

  async getStreamBalance(streamId: string): Promise<StreamBalance> {
    try {
      const response = await axios.get(`${this.baseURL}/streams/${streamId}/balance`, {
        headers: this.getHeaders(),
      });
      return response.data;
    } catch (error) {
      console.error('Failed to get stream balance:', error);
      throw error;
    }
  }
}

export default new ApiService();