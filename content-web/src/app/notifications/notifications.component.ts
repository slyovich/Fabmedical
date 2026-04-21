import { Component, OnInit } from '@angular/core';
import { Notification } from '../models/notification.model';
import { NotificationsService } from './notifications.service';

@Component({
  selector: 'app-notifications',
  templateUrl: './notifications.component.html',
  styleUrls: ['./notifications.component.css']
})
export class NotificationsComponent implements OnInit {
  public notifications: Notification[] = [];

  constructor(private notificationsService: NotificationsService) { }

  ngOnInit() {
    this.notificationsService.getNotifications().subscribe((res: Notification[]) => {
      this.notifications = res;
    });
  }
}
