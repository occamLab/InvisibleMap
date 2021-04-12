//
//  AddLocationButton.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/23/21.
//

import SwiftUI

struct AddLocationButton: View {
    @Binding var recording: Bool
    
    var body: some View {
        Button(action: {}){
            Image(systemName: "plus")
                .accessibility(label: Text("Add location"))
        }
        .buttonStyle(CircleButtonStyle())
        .opacity(recording ? 1 : 0.5)
        .disabled(recording ? false: true)
    }
}

struct AddLocationButton_Previews: PreviewProvider {
    @State static var recording = false
    
    static var previews: some View {
        AddLocationButton(recording: $recording)
    }
}
