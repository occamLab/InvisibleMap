//
//  AppController.swift
//  InvisibleMap
//
//  Created by Allison Li and Ben Morris on 9/22/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import Foundation

protocol AppController {
    associatedtype AppCommand
    associatedtype AppEvent
    
    func process(commands: [AppCommand])
    func process(event: AppEvent)
}
