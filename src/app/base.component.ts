import { OnInit } from "@angular/core/src/metadata/lifecycle_hooks";
import { GlobalVariables } from "./globals";
import { DOCUMENT } from '@angular/common'
import { Inject } from '@angular/core';

export class BaseComponent implements OnInit {


    homeUrl: string;
    productsUrl: string;
    vendorsUrl: string;
    ordersUrl: string;
    customersUrl: string;

    productId: number;
    vendorId: number;
    orderId: number;
    customerId: number;


    //the choise to go with GlobalVariables.userLanguage instad of local var is to be able to use this in services as well as components
    get lang(): string {

        return GlobalVariables.userLanguage;
    }
    set lang(language: string) {
        GlobalVariables.userLanguage = language;
    }

    constructor() {

        this.homeUrl = `/${this.lang}/home`;
        this.productsUrl = `/${this.lang}/products`;
        this.customersUrl = `/${this.lang}/customers`;
        this.ordersUrl = `/${this.lang}/orders`;
        this.vendorsUrl = `/${this.lang}/vendors`;
        
    }

    public ngOnInit(): void {

        this.lang = GlobalVariables.userLanguage;

        this.productId = Math.round(Math.random() * 100);
        this.customerId = Math.round(Math.random() * 100);
        this.orderId = Math.round(Math.random() * 100);
        this.vendorId = Math.round(Math.random() * 100);

    }

}