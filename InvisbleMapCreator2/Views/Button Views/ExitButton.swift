//
//  ExitButton.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/13/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct ExitButton: View {
    var body: some View {
        Button(action: {}){
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
