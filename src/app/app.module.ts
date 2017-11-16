import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';


import { AppComponent } from './app.component';
import { ProductsComponent } from './products/products.component';
import { VendorsComponent } from './vendors/vendors.component';
import { CustomersComponent } from './customers/customers.component';
import { OrdersComponent } from './orders/orders.component';
import { RouterModule } from '@angular/router';
import { Constants } from "./constants";
import { WelcomeComponent } from './welcome/welcome.component';

@NgModule({
  declarations: [
    AppComponent,
    ProductsComponent,
    VendorsComponent,
    CustomersComponent,
    OrdersComponent,
    WelcomeComponent
  ],
  imports: [
    BrowserModule,
    RouterModule.forRoot(Constants.appRoutes)
  ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule { }
