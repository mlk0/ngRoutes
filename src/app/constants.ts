import { AppComponent } from "./app.component";
import { ProductsComponent } from "./products/products.component";
import { VendorsComponent } from "./vendors/vendors.component";
import { OrdersComponent } from "./orders/orders.component";
import { CustomersComponent } from "./customers/customers.component";
import { WelcomeComponent } from "./welcome/welcome.component";

export class Constants {
    public static appRoutes = [
        { path: '', redirectTo: 'home', pathMatch: 'full' },
        { path: 'home', component:WelcomeComponent },
        { path: 'products', component:ProductsComponent },
        { path: 'vendors', component:VendorsComponent },
        { path: 'orders', component:OrdersComponent },
        { path: 'customers', component:CustomersComponent }
    ]
}
