import { Component, OnInit } from '@angular/core';
import { GlobalVariables } from '../globals';
import { BaseComponent } from '../base.component';

@Component({
  selector: 'app-welcome',
  templateUrl: './welcome.component.html',
  styleUrls: ['./welcome.component.css']
})
export class WelcomeComponent extends BaseComponent implements OnInit {

  constructor() {
    super();
  }

  productsUrl: string;

  ngOnInit() {
    this.productsUrl = `${this.lang}/products`;
  }

}
