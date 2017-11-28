import { OnInit } from "@angular/core/src/metadata/lifecycle_hooks";
import { GlobalVariables } from "./globals";
import { DOCUMENT } from '@angular/common'
import { Inject  } from '@angular/core';

export class BaseComponent implements OnInit{

  

    //the choise to go with GlobalVariables.userLanguage instad of local var is to be able to use this in services as well as components
    get lang():string {
        
        return GlobalVariables.userLanguage;
    }
    set lang(language:string) {
        GlobalVariables.userLanguage = language;
    }
    
    ngOnInit(): void {   

        this.lang = GlobalVariables.userLanguage;
    }
  
}