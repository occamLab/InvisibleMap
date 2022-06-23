//
//  ExitButton.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/13/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

// Defines a button style for all the rectangle buttons on the RecordMap screen (excluding the AddLocation button)
struct RectangleButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: 80, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .foregroundColor(Color(UIColor.systemBackground))
                    .opacity(0.7))
    }
}

struct ExitButton: View {
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
                    AppController.shared.cancelRecordingRequested() // Tells the state machine to cancel the map recording
                },
                secondaryButton: .cancel()
            )
        }
    }
}

/*
struct ExitButton_Previews: PreviewProvider {
    static var previews: some View {
        ExitButton()
    }
}
*/
