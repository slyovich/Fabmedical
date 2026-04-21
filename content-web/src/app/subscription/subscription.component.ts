import { Component } from '@angular/core';
import { NotificationsService } from '../notifications/notifications.service';

@Component({
  selector: 'app-subscription',
  templateUrl: './subscription.component.html',
  styleUrls: ['./subscription.component.css']
})
export class SubscriptionComponent {
  public message = '';
  public publisher = '';
  public type = 'speaker';

  public isSubmitting = false;
  public successMessage = '';
  public errorMessage = '';

  constructor(private notificationsService: NotificationsService) { }

  public onSubmit(): void {
    this.successMessage = '';
    this.errorMessage = '';

    const message = this.message.trim();
    const publisher = this.publisher.trim();

    if (!message || !publisher || (this.type !== 'speaker' && this.type !== 'session')) {
      this.errorMessage = 'Please complete all fields with valid values.';
      return;
    }

    if (message.length > 255 || publisher.length > 50) {
      this.errorMessage = 'Please respect field length limits.';
      return;
    }

    const notification = {
      message,
      publisher,
      type: this.type,
      datetime: new Date().toISOString()
    };

    this.isSubmitting = true;
    this.notificationsService.createNotification(notification).subscribe(
      () => {
        this.successMessage = 'Notification sent successfully.';
        this.message = '';
        this.publisher = '';
        this.type = 'speaker';
      },
      () => {
        this.errorMessage = 'Unable to send notification. Please try again.';
      },
      () => {
        this.isSubmitting = false;
      }
    );
  }
}
