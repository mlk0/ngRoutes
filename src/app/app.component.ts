import { Component, Inject } from '@angular/core';
import { OnInit } from '@angular/core/src/metadata/lifecycle_hooks';
import { Router, ActivatedRoute } from '@angular/router';
import { GlobalVariables } from './globals';
import { NgModule } from '@angular/core';
import { BaseComponent } from './base.component';
import { Constants } from './constants';

import { DOCUMENT } from '@angular/common'


@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent extends BaseComponent implements OnInit {

  homeLink: string;
  productsLink: string;
  customersLink: string;
  ordersLink: string;
  vendorsLink: string;

  constructor(private router: Router, private route: ActivatedRoute,
    @Inject(DOCUMENT) private document: Document) {
    super();
  }


  ngOnInit(): void {


    /* In order to deep link I need to have the path available in this.router.url
       Since this is not the case, I am using the address bar through the injected DOCUMENT */
    console.log(this.document.location.href);
    let pathname = this.document.location.pathname;

    //if there is no value in the lang (which would be the case in deep linking) just take it from the url if it's there  
    if (this.lang == '') {
      if (pathname.toLowerCase().startsWith('/en') || pathname.toLocaleLowerCase().startsWith('/fr')) {

        let routeParts: string[] = pathname.split('/');
        this.lang = routeParts[1];
      }
    }

    console.log(`AppComponent.ngOnInit - language : ${this.lang} `);
    
    //setting the localized menu links
    let currentLanguage = this.lang == '' ? Constants.english : this.lang;
    this.homeLink = currentLanguage == Constants.english ? Constants.home_en : Constants.home_fr;
    this.productsLink = currentLanguage == Constants.english ? Constants.products_en : Constants.products_fr;
    this.customersLink = currentLanguage == Constants.english ? Constants.customers_en : Constants.customers_fr;
    this.ordersLink = currentLanguage == Constants.english ? Constants.orders_en : Constants.orders_fr;
    this.vendorsLink = currentLanguage == Constants.english ? Constants.vendors_en : Constants.vendors_fr;

  }
 


  toggleLang() {

    let currentLanguage = this.lang == '' ? Constants.english : this.lang;

    if (currentLanguage == Constants.english) {
      this.lang = Constants.french;
    }
    else {
      this.lang = Constants.english;
    }

    //call to the OnInit in order to reset the binding in the templates that were implemented with interpolation type of binding
    //super.ngOnInit();

    console.log(`this.router.url : ${this.router.url}`);

    let currentRoute = this.router.url;

    if (currentRoute.toLowerCase().startsWith('/en') || currentRoute.toLocaleLowerCase().startsWith('/fr')) {
      let routeParts: string[] = currentRoute.split('/');
      console.log(`routeParts : ${routeParts}`);
      // '','en','customers'
      routeParts.splice(0, 2);
      console.log(`spliced routeParts : ${routeParts}`);
      currentRoute = routeParts.join('/');
      console.log(`languageAgnosticRoute : ${currentRoute}`);
    }

    this.router.navigate([`${this.lang}/${currentRoute}`]);
    this.ngOnInit();
  }
 

}


