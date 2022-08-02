//
//  InvisibleMapNavigationView.swift
//  InvisibleMap2
//
//  Created by occamlab on 8/2/22.
//  Copyright © 2022 Occam Lab. All rights reserved.
//

import SwiftUI

struct InvisibleMapNavigationView: View {
    
    @ObservedObject var navigateGlobalState = NavigateGlobalState.shared
    
    var body: some View {
        VStack {
            
            // Show instructions if there are any
            if navigateGlobalState.instructionWrapper.text != nil {
                InstructionOverlay(instruction: $navigateGlobalState.instructionWrapper.text)
                    .animation(.easeInOut)
            }
            if navigateGlobalState.instructionWrapper != .findTag && navigateGlobalState.tagFound {
                // for testing purposes; TODO: update text with directions
                //Text("Binary direction: \(navigateGlobalState.binaryDirection)")
                //Text("Clock direction: \(navigateGlobalState.clockDirection)")
                let direction = binaryDirectionToDirectionText(dir: navigateGlobalState.binaryDirectionKey)
                Text("\(direction)")
            }
            TagDetectionButton(navigateGlobalState: navigateGlobalState)
                .environmentObject(InvisibleMapController.shared.mapNavigator)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .padding()
    }
}

struct InvisibleMapNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        InvisibleMapNavigationView()
    }
}
