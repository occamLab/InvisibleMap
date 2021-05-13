//
//  ManageLocationsButton.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/16/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct ManageLocationsButton: View {
    @ObservedObject var recordGlobalState: RecordGlobalState
    @State var showLocations = false // Tracks whether locations list is showing
    
    var body: some View {
        Button(action: {
            showLocations = true
            AppController.shared.viewLocationsRequested() // Tells the state machine that the manage locations menu has been opened
        }){
            Image(systemName: "line.horizontal.3")
                .accessibility(label: Text("Manage Locations"))
        }
        .buttonStyle(RectangleButtonStyle())
        .sheet(isPresented: $showLocations, onDismiss: {
            AppController.shared.dismissLocationsRequested() // Tells the state machine that the manage locations menu has been closed
        }) {
            ManageLocationsView(recordGlobalState: recordGlobalState, showLocations: $showLocations)
        }

    }
}

struct ManageLocationsButton_Previews: PreviewProvider {
    @StateObject static var recordGlobalState = RecordGlobalState()

    static var previews: some View {
        ManageLocationsButton(recordGlobalState: recordGlobalState)
    }
}
