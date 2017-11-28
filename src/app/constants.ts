import { AppComponent } from "./app.component";
import { ProductsComponent } from "./products/products.component";
import { VendorsComponent } from "./vendors/vendors.component";
import { OrdersComponent } from "./orders/orders.component";
import { CustomersComponent } from "./customers/customers.component";
import { WelcomeComponent } from "./welcome/welcome.component";
import { GlobalVariables } from "./globals";

export class Constants {
    public static appRoutes = [

        { path: '', redirectTo: 'home', pathMatch: 'full' },
        { path: 'home', component:WelcomeComponent },    
        { path: 'products', component:ProductsComponent },
        { path: 'vendors', component:VendorsComponent },
        { path: 'orders', component:OrdersComponent },
        { path: 'customers', component:CustomersComponent },
       
        { path: 'en/home', component:WelcomeComponent },
        { path: 'fr/home', component:WelcomeComponent },

        //{ path: `${GlobalVariables.userLanguage}/home`, component:WelcomeComponent },
        // { path: 'fr/home', component:WelcomeComponent },

        { path: 'en/products', component:ProductsComponent },
        { path: 'fr/products', component:ProductsComponent },

        // { path: `${GlobalVariables.userLanguage}/products`, component:ProductsComponent },
        

        { path: 'en/vendors', component:VendorsComponent },
        { path: 'fr/vendors', component:VendorsComponent },
       
        { path: 'en/orders', component:OrdersComponent },
        { path: 'fr/orders', component:OrdersComponent },

        { path: 'en/customers', component:CustomersComponent },
        { path: 'fr/customers', component:CustomersComponent },


   


    ]

    public static home_en : string = "Home";
    public static products_en : string = "Products";
    public static customers_en : string = "Customers";
    public static orders_en : string = "Orders";
    public static vendors_en : string = "Vendors";
  
    public static home_fr : string = "Accueil";
    public static products_fr : string = "Des produits";
    public static customers_fr : string = "Les clients";
    public static orders_fr : string = "Ordres";
    public static vendors_fr : string = "Vendeurs";

    public static english : string = 'en';
    public static french : string = 'fr';
}
