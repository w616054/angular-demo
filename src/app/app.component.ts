import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div style="text-align: center; padding: 50px;">
      <h1>Welcome to Angular K8s Demo!</h1>
      <p>This is a simple Angular application deployed on Kubernetes.</p>
      <p>Version: {{ version }}</p>
    </div>
  `,
  styles: [`
    h1 {
      color: #dd0031;
    }
    p {
      font-size: 18px;
      color: #333;
    }
  `]
})
export class AppComponent {
  version = '1.1.0';
}
