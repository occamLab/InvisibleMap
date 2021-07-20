//
//  RecordTagButton.swift
//  InvisibleMapCreator2
//
//  Created by tad on 7/16/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct RecordTagButton: View {
    @EnvironmentObject var mapRecorder: MapRecorder
    
    var body: some View {
        Button(action: {
            var logging = "Button pressed: switching recordTag from \(self.mapRecorder.recordTag) "
            self.mapRecorder.recordTag.toggle()
            logging = logging + "to \(self.mapRecorder.recordTag)"
            print(logging)
        }){
            Text(self.mapRecorder.recordTag ? "Stop Recording Tags" : "Start Recording Tags")
                .frame(width: 300, height: 60)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .foregroundColor(self.mapRecorder.recordTag ? .red : .blue)
                        .opacity(self.mapRecorder.seesTag ? 1 : 0.5))
        }
        .disabled(!self.mapRecorder.seesTag)
        // Button styling for the AddLocation button
    }
}

struct RecordTagButton_Previews: PreviewProvider {
    static var previews: some View {
        RecordTagButton().environmentObject(AppController.shared.mapRecorder)
    }
}
