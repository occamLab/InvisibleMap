//
//  InvisibleMapController.swift
//  InvisibleMap2
//
//  Created by tad on 9/22/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import Foundation

class InvisibleMapController: AppController {
    public static var shared = InvisibleMapController()
    private var state = AppState.initialState
    
    public var arViewer: ARView?
    
    func process(commands: [AppState.Command]) {
        for command in commands {
            switch command {
                default: break;
            }
        }
    }
    
    func process(event: AppState.Event) {
        process(commands: state.handle(event: event))
    }
}
