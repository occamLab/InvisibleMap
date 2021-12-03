//
//  ExitButton.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/13/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct ExitButton: View {
    @Environment(\.presentationMode) var mode: Binding<PresentationMode> // Tracks whether the RecordMap screen is being presented

    var body: some View {
        Button(action: {
            self.mode.wrappedValue.dismiss()
            InvisibleMapCreatorController.shared.process(event: .CancelRecordingRequested) // Tells the state machine to cancel the map recording
        }){
            Image(systemName: "xmark")
                .accessibility(label: Text("Cancel Map"))
        }
        .buttonStyle(RectangleButtonStyle())
    }
}

struct ExitButton_Previews: PreviewProvider {
    static var previews: some View {
        ExitButton()
    }
}
