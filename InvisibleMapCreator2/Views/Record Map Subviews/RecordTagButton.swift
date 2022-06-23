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
    @State private var showingAlert = false
    
    var body: some View {
        // with red record/stop button
    /*
        ZStack{
            if self.mapRecorder.recordTag {
            // Stop recording button - when pressed, recording should stop and an alert to save the map should pop-up
                Button(action: {
                    SaveButton().alert()
                }) {
                    ZStack{
                        // TODO: show stop button when camera is recording a tag or the route
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 40, height: 40)
                        
                        Circle()
                            .stroke(Color.white, lineWidth: 6)
                            .frame(width: 85, height: 85)
                    }
                }
            } else {
            // Start recording button
                Button(action: {
                    if self.mapRecorder.seesTag {
                        self.mapRecorder.recordTag.toggle()
                    } else {
                        recordGlobalState.instructionWrapper.transition(tagFound: recordGlobalState.tagFound, recordTagRequested: true)
                    }
                }) {
                    ZStack{
                            // if camera doesn't detect tag yet, grey out record button, letting users know that they can't start recording yet
                            if !self.mapRecorder.seesTag {
                                Circle()
                                    .fill(Color.red.opacity(0.6))
                                    .frame(width: 70, height: 70)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 70, height: 70)
                            }
                        Circle()
                            .stroke(Color.white, lineWidth: 6)
                            .frame(width: 85, height: 85)
                    }
                }
            }
        } */
        
        
        Button(action: {
            if self.mapRecorder.seesTag {
                self.mapRecorder.recordTag.toggle()
            } else {
                recordGlobalState.instructionWrapper.transition(tagFound: recordGlobalState.tagFound, recordTagRequested: true)
            }
            // check ???
            if recordGlobalState.tagMarked {
                recordGlobalState.instructionWrapper.transition(tagFound: recordGlobalState.tagFound, locationRequested: true, recordTagRequested: true) // Sends a marked tag reminder to the user to find next tag after marking a tag
            }
        }){
            Text(!self.mapRecorder.recordTag ? "Mark Tag" : "Tag was Marked")
                .frame(width: 300, height: 60)
                                .foregroundColor(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .foregroundColor(!self.mapRecorder.recordTag ? .green : .gray)
                                        .opacity(self.mapRecorder.seesTag ? 1 : 0.5))
            
            
            /*
            
                if !self.mapRecorder.recordTag {
                    // if camera doesn't detect tag yet, grey out mark tag button, letting users know that they can't mark the tag before detecting a tag
                    if !self.mapRecorder.seesTag {
                        Text("Mark Tag")
                            .frame(width: 300, height: 60)
                            .foregroundColor(.white)
                            .background(
                                Rectangle()
                                    .fill(Color.green.opacity(0.6))
                                    .frame(width: 70, height: 70)
                        )
                    } else {
                        Text("Mark Tag")
                            .frame(width: 300, height: 60)
                            .foregroundColor(.white)
                            .background(
                                Rectangle()
                                    .fill(Color.green)
                                    .frame(width: 70, height: 70)
                            )
                    }
                } else {
                    Text("Tag was Marked")
                        .frame(width: 300, height: 60)
                        .foregroundColor(.white)
                        .background(
                            Rectangle()
                                .fill(Color.gray)
                                .frame(width: 70, height: 70)
                        )
                } */
                   
            
            
            
            
            /*
            Text(self.mapRecorder.recordTag ? "Stop Recording Tags" : "Start Recording Tags")
                
            
                .frame(width: 300, height: 60)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .foregroundColor(self.mapRecorder.recordTag ? .red : .green)
                        .opacity(self.mapRecorder.seesTag ? 1 : 0.5)) */
      //  }
        //.disabled(!self.mapRecorder.seesTag)
        }
    }
}




struct RecordTagButton_Previews: PreviewProvider {
    @StateObject static var recordGlobalState = RecordGlobalState()
    
    static var previews: some View {
        RecordTagButton(recordGlobalState: recordGlobalState).environmentObject(AppController.shared.mapRecorder)
    }
}
    
