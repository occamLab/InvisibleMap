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
                self.mapRecorder.tagRecordingState = true
                self.mapRecorder.tagWasRecorded = false
                //self.mapRecorder.tagRecordingState.toggle() // toggle between green start and red stop button
                print("current tag recording state: \(self.mapRecorder.tagRecordingState)")
                //if self.mapRecorder.tagRecordingState {
                    self.mapRecorder.tagRecordingStartTime = NSDate().timeIntervalSince1970
                
            } else {
                recordGlobalState.instructionWrapper.transition(tagFound: recordGlobalState.tagFound, markTagRequested: true)
            }
        }){
            Text(!self.mapRecorder.tagRecordingState ? "Start Recording Tag" : "Stop Recording Tag")
                .frame(width: 300, height: 60)
                                .foregroundColor(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .foregroundColor(.green)
                                        .opacity((self.mapRecorder.seesTag && !self.mapRecorder.tagRecordingState) ? 1 : 0.5))  // only "clickable"/full opacity if a tag is seen and not already in tag recording state
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
