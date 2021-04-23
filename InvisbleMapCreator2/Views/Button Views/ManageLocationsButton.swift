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
