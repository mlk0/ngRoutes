import { Component, OnInit } from '@angular/core';
import { BaseComponent } from '../base.component';

@Component({
  selector: 'app-customers',
  templateUrl: './customers.component.html',
  styleUrls: ['./customers.component.css']
})
export class CustomersComponent extends BaseComponent implements OnInit {

  constructor() {super();
  }

  ngOnInit() {
  }

}
