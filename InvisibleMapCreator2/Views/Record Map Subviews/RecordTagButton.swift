//
//  RecordTagButton.swift
//  InvisibleMapCreator2
//
//  Created by tad on 7/16/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct RecordTagButton: View {
    var body: some View {
        Button(action: {
            AppController.shared.recordTagRequested()
        }){
            Text("Record Tag")
        }
        // Button styling for the AddLocation button
        .frame(width: 200, height: 60)
        .foregroundColor(.white)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .foregroundColor(.blue))
    }
}

struct RecordTagButton_Previews: PreviewProvider {
    static var previews: some View {
        RecordTagButton()
    }
}
