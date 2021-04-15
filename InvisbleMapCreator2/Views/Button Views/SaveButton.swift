//
//  SaveButton.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/13/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct SaveButton: View {
    var body: some View {
        Button(action: {}){
            Text("Save")
        }
        .buttonStyle(RectangleButtonStyle())
    }
}

struct SaveButton_Previews: PreviewProvider {
    static var previews: some View {
        SaveButton()
    }
}
