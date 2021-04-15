//
//  UndoButton.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/23/21.
//

import SwiftUI

struct UndoButton: View {
    @Binding var recording: Bool
    
    var body: some View {
        Button(action: {}){
            Image(systemName: "arrow.uturn.backward")
                .accessibility(label: Text("Undo"))
        }
        .buttonStyle(RectangleButtonStyle())
        .opacity(recording ? 1 : 0.5)
        .disabled(recording ? false: true)
    }
}

struct UndoButton_Previews: PreviewProvider {
    @State static var recording = false
    static var previews: some View {
        UndoButton(recording: $recording)
    }
}
