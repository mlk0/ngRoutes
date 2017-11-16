import { AppComponent } from "./app.component";
import { ProductsComponent } from "./products/products.component";
import { VendorsComponent } from "./vendors/vendors.component";
import { OrdersComponent } from "./orders/orders.component";
import { CustomersComponent } from "./customers/customers.component";

export class Constants {
    public static appRoutes = [
        { path: '', redirectTo: 'home', pathMatch: 'full' },
        { path: 'home', component:AppComponent },
        { path: 'products', component:ProductsComponent },
        { path: 'vendors', component:VendorsComponent },
        { path: 'orders', component:OrdersComponent },
        { path: 'customers', component:CustomersComponent }
    ]
}
