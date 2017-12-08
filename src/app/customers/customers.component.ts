import { Component, OnInit } from '@angular/core';
import { BaseComponent } from '../base.component';
import { ActivatedRoute } from '@angular/router';

@Component({
  selector: 'app-customers',
  templateUrl: './customers.component.html',
  styleUrls: ['./customers.component.css']
})
export class CustomersComponent extends BaseComponent implements OnInit {

  constructor(activatedRoute : ActivatedRoute) {
    super();
    activatedRoute.params.subscribe(p=>{
      if(p["id"]){
        console.log(`CustomersComponent - CustomerId : ${p["id"]}`);
        this.customerId = p["id"]
      }
      
    });
  }

  ngOnInit() {
    super.ngOnInit();
  }

}
