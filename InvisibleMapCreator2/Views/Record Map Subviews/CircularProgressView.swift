//
//  CircularProgressBarView.swift
//  InvisibleMap2
//
//  Created by occamlab on 7/15/22.
//  Copyright © 2022 Occam Lab. All rights reserved.
//

import SwiftUI

struct CircularProgressView: View {
    //@ObservedObject var recordGlobalState: RecordGlobalState
    let progress: Double
        
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.blue.opacity(0.5),
                    lineWidth: 30
                )
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(
                    Color.blue,
                    style: StrokeStyle(
                        lineWidth: 30,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                // 1
                //.animation(.easeOut, value: progress)
                .animation(.easeOut(duration: 1))

        }
    }
}

struct CircularProgressView_Previews: PreviewProvider {
    static var previews: some View {
        Text("placeholder")
        //CircularProgressView()
    }
}
