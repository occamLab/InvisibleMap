//
//  CreatorExitButton.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/13/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//
//  Exit Button for Invisible Map Creator (could possible merge with Exit button for IM and put if else statements)

import SwiftUI

struct CreatorExitButton: View {
    @Environment(\.presentationMode) var mode: Binding<PresentationMode> // Tracks whether the RecordMap screen is being presented
    @State private var showCancelConfirmation = false

    var body: some View {
        Button(action: {
            showCancelConfirmation = true
        }){
            Image(systemName: "xmark")
                .accessibility(label: Text("Cancel Map"))
        }
        .buttonStyle(RectangleButtonStyle())
        .alert(isPresented: $showCancelConfirmation) {
            Alert(
                title: Text("Would you like to exit without saving the map?"),
                primaryButton: .destructive(Text("Exit")) {
                print("canceling map without saving...")
                self.mode.wrappedValue.dismiss()
                InvisibleMapCreatorController.shared.process(event: .CancelRecordingRequested) // Tells the state machine to cancel the map recording
                },
                secondaryButton: .cancel()
            )
        }
    }
}

struct CreatorExitButton_Previews: PreviewProvider {
    static var previews: some View {
        CreatorExitButton()
    }
}
