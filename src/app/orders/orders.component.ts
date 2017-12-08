import { Component, OnInit } from '@angular/core';
import { BaseComponent } from '../base.component';
import { ActivatedRoute } from '@angular/router';

@Component({
  selector: 'app-orders',
  templateUrl: './orders.component.html',
  styleUrls: ['./orders.component.css']
})
export class OrdersComponent extends BaseComponent implements OnInit {

  constructor(activatedRoute : ActivatedRoute) {
    super();
    activatedRoute.params.subscribe(p=>{
      if(p["id"]){
        console.log(`OrdersComponent - OrderId : ${p["id"]}`);
        this.customerId = p["id"]
      }
      
    });
  }

  ngOnInit() {
    super.ngOnInit();
  }

}
