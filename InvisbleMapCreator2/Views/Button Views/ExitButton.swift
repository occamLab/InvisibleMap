//
//  ExitButton.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/13/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

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
    @Environment(\.presentationMode) var mode: Binding<PresentationMode>

    var body: some View {
        Button(action: {
            self.mode.wrappedValue.dismiss()
            AppController.shared.cancelRecordingRequested() // Request cancel recording in state machine
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
