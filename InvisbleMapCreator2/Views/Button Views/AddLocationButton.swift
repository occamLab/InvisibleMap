//
//  AddLocationButton.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/16/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct AddLocationButton: View {
    var body: some View {
        Button(action: {
            //TODO: Save location button
        }){
            HStack {
                Image(systemName: "plus")
                Text("Add Location")
            }
        }
        .frame(width: 200, height: 40)
        .foregroundColor(.white)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .foregroundColor(.green))
    }
}

struct AddLocationButton_Previews: PreviewProvider {
    static var previews: some View {
        AddLocationButton()
    }
}
