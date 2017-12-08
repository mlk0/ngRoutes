import { Component, OnInit } from '@angular/core';
import { BaseComponent } from '../base.component';
import { ActivatedRoute } from '@angular/router';


@Component({
  selector: 'app-products',
  templateUrl: './products.component.html',
  styleUrls: ['./products.component.css']
})
export class ProductsComponent extends BaseComponent implements OnInit {
  productId: any;

  constructor(activatedRoute: ActivatedRoute) {
    super();

    activatedRoute.params.subscribe(routeParameters => {
      if (routeParameters) {
        let id = routeParameters["id"];
        console.log(`routeParameters["id"] = ${id}`);
        this.productId = id;
      }
      else {
        console.log('no route params passed');
      }
    }
    );

  }

  ngOnInit() {
    super.ngOnInit();
  }

}
