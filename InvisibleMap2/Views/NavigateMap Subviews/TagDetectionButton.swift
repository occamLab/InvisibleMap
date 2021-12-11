//
//  TagDetectionButton.swift
//  InvisibleMap2
//
//  Created by Allison Li and Ben Morris on 12/10/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct TagDetectionButton: View {
    @EnvironmentObject var mapNavigator: MapNavigator
    @ObservedObject var navigateGlobalState: NavigateGlobalState
    
    var body: some View {
        Button(action: {
            self.mapNavigator.detectTags.toggle()
            if self.mapNavigator.detectTags {
                for child in InvisibleMapController.shared.arViewer!.detectionNode.childNodes {
                    child.removeFromParentNode()
                }
            }
        }){
            Text(self.mapNavigator.detectTags ? "Stop Tag Detection" : "Start Tag Detection")
                .frame(width: 300, height: 60)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .foregroundColor(self.mapNavigator.detectTags ? .red : .blue))
        }
    }
}

struct RecordTagButton_Previews: PreviewProvider {
    @StateObject static var navigateGlobalState = NavigateGlobalState()
    
    static var previews: some View {
        TagDetectionButton(navigateGlobalState: navigateGlobalState).environmentObject(InvisibleMapController.shared.mapNavigator)
    }
}
