import { Component, OnInit } from '@angular/core';
import { BaseComponent } from '../base.component';
import { ActivatedRoute } from '@angular/router';

@Component({
  selector: 'app-vendors',
  templateUrl: './vendors.component.html',
  styleUrls: ['./vendors.component.css']
})
export class VendorsComponent extends BaseComponent implements OnInit {

  constructor(activatedRoute : ActivatedRoute) {
    super();
    activatedRoute.params.subscribe(p=>{
      if(p["id"]){
        console.log(`VendorsComponent - VendorId : ${p["id"]}`);
        this.customerId = p["id"]
      }
      
    });
  }

  ngOnInit() {
    super.ngOnInit();
  }

}
