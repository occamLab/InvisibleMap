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
    @ObservedObject var recordGlobalState: RecordGlobalState
    
    var body: some View {
        Button(action: {
            if self.mapRecorder.seesTag {
                self.mapRecorder.recordTag.toggle()
            } else {
                recordGlobalState.instructionWrapper.transition(tagFound: recordGlobalState.tagFound, recordTagRequested: true)
            }
        }){
            Text(self.mapRecorder.recordTag ? "Stop Recording Tags" : "Start Recording Tags")
                .frame(width: 300, height: 60)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .foregroundColor(self.mapRecorder.recordTag ? .red : .blue)
                        .opacity(self.mapRecorder.seesTag ? 1 : 0.5))
        }
        //.disabled(!self.mapRecorder.seesTag)
    }
}

struct RecordTagButton_Previews: PreviewProvider {
    @StateObject static var recordGlobalState = RecordGlobalState()
    
    static var previews: some View {
        RecordTagButton(recordGlobalState: recordGlobalState).environmentObject(AppController.shared.mapRecorder)
    }
}
