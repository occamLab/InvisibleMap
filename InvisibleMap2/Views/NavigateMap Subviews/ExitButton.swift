//
//  ExitButton.swift
//  InvisibleMap2
//
//  Created by occamlab on 6/24/22.
//  Copyright © 2022 Occam Lab. All rights reserved.
//
//  Exit Button for Invisible Map 

import SwiftUI

struct ExitButton: View {
    @Environment(\.presentationMode) var mode: Binding<PresentationMode>
    @State private var showCancelConfirmation = false
    var mapName: String

    var body: some View {
        Button(action: {
            showCancelConfirmation = true
        }){
            Image(systemName: "xmark")
                .accessibility(label: Text("Exit Navigation"))
        }
        .buttonStyle(RectangleButtonStyle())
        .alert(isPresented: $showCancelConfirmation) {
            Alert(
                title: Text("Would you like to stop navigating?"),
                primaryButton: .destructive(Text("Exit")) {
                print("exiting map navigation view...")
                self.mode.wrappedValue.dismiss()
             //   NavigationLink(destination: SelectPathView())
                InvisibleMapController.shared.process(event: .LeaveMapRequested(mapFileName: mapName)) // Tells the state machine to cancel the map navigating
                },
                secondaryButton: .cancel()
            )
        }
    }
}
