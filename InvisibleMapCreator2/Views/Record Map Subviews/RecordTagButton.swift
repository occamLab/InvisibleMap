//
//  tagRecordingStateButton.swift
//  InvisibleMapCreator2
//
//  Created by tad on 7/16/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct RecordTagButton: View {
    @EnvironmentObject var mapRecorder: MapRecorder
    @ObservedObject var recordGlobalState: RecordGlobalState
    @State private var showingAlert = false
    
    var body: some View {
        Button(action: {
            if self.mapRecorder.seesTag {
                self.mapRecorder.previousTagRecordedState = self.mapRecorder.tagRecordingState
                print("previous tag recording state: \(self.mapRecorder.previousTagRecordedState)")
                print("current tag recording state: \(self.mapRecorder.tagRecordingState)")
                self.mapRecorder.tagRecordingState.toggle() // toggle between green start and red stop button
                if self.mapRecorder.tagRecordingState {
                    self.mapRecorder.tagRecordingStartTime = NSDate().timeIntervalSince1970
                } else {
                    self.mapRecorder.tagRecordingStartTime = 0.0
                }
                
            } else {
                recordGlobalState.instructionWrapper.transition(tagFound: recordGlobalState.tagFound, markTagRequested: true)
            }
        }){
            Text(!self.mapRecorder.tagRecordingState ? "Start Recording Tag" : "Stop Recording Tag")
                .frame(width: 300, height: 60)
                                .foregroundColor(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .foregroundColor(.green) // when at recording state red, stop button shows
                                        .opacity(self.mapRecorder.seesTag ? 1 : 0.5))  // changes shade of record tag green button if camera is not detecting tags
        }
        //.disabled(!self.mapRecorder.seesTag)
    }
}

struct tagRecordingStateButton_Previews: PreviewProvider {
    @StateObject static var recordGlobalState = RecordGlobalState()
    
    static var previews: some View {
        RecordTagButton(recordGlobalState: recordGlobalState).environmentObject(InvisibleMapCreatorController.shared.mapRecorder)
    }
}
