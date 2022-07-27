//
//  GetDirectionsButton.swift
//  InvisibleMap2
//
//  Created by Joyce Chung on 7/21/22.
//  Copyright © 2022 Occam Lab. All rights reserved.
//

import SwiftUI

struct GetDirectionsButton: View {
    @ObservedObject var navigateGlobalState = NavigateGlobalState.shared
    
    var body: some View {
        // button for navigation directions
        Button(action: {
            print("angle - cos value: \(navigateGlobalState.navigation.cosValue)")
            // set previous key
            navigateGlobalState.previousBinaryDirectionKey = navigateGlobalState.binaryDirectionKey
            // update key
            navigateGlobalState.binaryDirectionKey = navigateGlobalState.navigation.getDirections().binaryDirectionKey
            print("just key: \(navigateGlobalState.binaryDirectionKey)")
            // update direction
            let direction = binaryDirectionToDirectionText(dir: navigateGlobalState.binaryDirectionKey)
            
            print("angle - binary direction: \(direction)")
            print("binary direction updated")
            
            navigateGlobalState.clockDirectionKey = navigateGlobalState.navigation.getDirections().clockDirectionKey
            navigateGlobalState.clockDirection = clockDirectionToDirectionText(dir: navigateGlobalState.clockDirectionKey)
            
            print("angle - clock direction: \(navigateGlobalState.clockDirection)")
            print("clock direction updated")
        }) {
            Image(systemName: "paperplane")
                .imageScale(.large)
                .foregroundColor(Color.primary)
                .accessibility(label: Text("Get directions button"))
        }
        .buttonStyle(RectangleButtonStyle())
    }
}
