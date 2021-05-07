//
//  ManageLocationsButton.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/16/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct ManageLocationsButton: View {
    var body: some View {
        /*
         @ObservedObject var popoverViewWrapper = GlobalState.shared.popoverViewWrapper // Track changes to popover UI
         @State var showPopover = false // Track whether popover is showing
         @Binding var recording: Bool // Track whether map is currently being recorded
         
         func buildPopoverView() -> some View {
             switch popoverViewWrapper.popoverUI {
             case .optionsMenu:
                 return AnyView(SideMenuView())
             case .recordMap:
                 return AnyView(Text("Record Map"))
             }
         }
         
         var body: some View {
             Button(action: {
                 showPopover = true
                 AppController.shared.optionsMenuRequested() // Request options menu in state machine on button click
             }){
                 Text("Menu")
                     .accessibility(label: Text("Options menu"))
             }
             .buttonStyle(RectangleButtonStyle())
             .opacity(recording ? 0.5 : 1)
             .disabled(recording ? true: false)
             .sheet(isPresented: $showPopover, onDismiss: {
                 AppController.shared.mainScreenRequested() // Request main screen in state machine on dismiss
             }) {
                 buildPopoverView() // Build popover UI
             }
         }
         */
        Button(action: {
            //TODO: Save button action
        }){
            Image(systemName: "line.horizontal.3")
                .accessibility(label: Text("Manage Locations"))
        }
        .buttonStyle(RectangleButtonStyle())
    }
}

struct ManageLocationsButton_Previews: PreviewProvider {
    static var previews: some View {
        ManageLocationsButton()
    }
}
