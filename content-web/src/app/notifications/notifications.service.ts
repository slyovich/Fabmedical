import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Notification } from '../models/notification.model';

@Injectable({
  providedIn: 'root'
})
export class NotificationsService {

  constructor(private http: HttpClient) { }

  public getNotifications() {
    return this.http.get<Notification[]>('/api/notifications');
  }

  public createNotification(notification: { message: string; datetime: string; publisher: string; type: string; }) {
    return this.http.post('/api/notifications', notification);
  }
}
