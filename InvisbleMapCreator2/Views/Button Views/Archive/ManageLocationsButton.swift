//
//  ManageLocationsButton.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/23/21.
//

import SwiftUI

struct ManageLocationsButton: View {
    @Binding var recording: Bool
    
    var body: some View {
        Button(action: {}){
            Image(systemName: "map")
                .accessibility(label: Text("Manage locations"))
        }
        .buttonStyle(CircleButtonStyle())
        .opacity(recording ? 1 : 0.5)
        .disabled(recording ? false: true)
    }
}

struct ManageLocationsButton_Previews: PreviewProvider {
    @State static var recording = false
    
    static var previews: some View {
        ManageLocationsButton(recording: $recording)
    }
}
