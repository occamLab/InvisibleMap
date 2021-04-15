//
//  RecordMapButton.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/23/21.
//

import SwiftUI

struct RecordMapButton: View {
    @Binding var recording: Bool // Track whether map is currently being recorded

    var body: some View {
        Button(action: {
            withAnimation {
                recording.toggle()
                print(recording)
            }
            if recording {
                AppController.shared.startRecordingRequested() // Request start recording in state machine
            } else {
                AppController.shared.stopRecordingRequested() // Request stop recording in state machine
            }
        }){
            ZStack {
                Circle()
                    .stroke(lineWidth: 6)
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)

                RoundedRectangle(cornerRadius: recording ? 8 : 68 / 2)
                    .foregroundColor(.red)
                    .frame(width: recording ? 32 : 68, height: recording ? 32 : 68)
            }
            .animation(.linear(duration: 0.2))
            .accessibility(label: Text("Record map"))
        }
    }
}

struct RecordMapButton_Previews: PreviewProvider {
    @State static var recording = false
    static var previews: some View {
        RecordMapButton(recording: $recording)
    }
}
