//
//  MenuView.swift
//  InvisibleMapCreator2
//
//  Created by Joyce Chung on 6/9/22.
//  Copyright © 2022 Occam Lab. All rights reserved.
//

import SwiftUI

struct MenuView: View {
    var body: some View {
        VStack(alignment: .leading) {
            
            /// Tutorials/Help
            HStack {
                Button(action: {
                    // TODO: make help/tutorials
                    Text("pressed help button")
                }) {
                    Image(systemName: "questionmark")
                        .imageScale(.large)
                        .foregroundColor(.black)
                    Text("Help")
                        .foregroundColor(.black)
                        .font(.headline)
                }
                .accessibilityLabel(Text("Help button"))
                
            }
            .padding(.top, 100)
            
            /// Settings
            HStack {
                Button(action: {
                    // TODO: make settings
                    Text("pressed settings button")
                }) {
                    Image(systemName: "gearshape")
                        .imageScale(.large)
                        .foregroundColor(.black)
                    Text("Settings")
                        .foregroundColor(.black)
                        .font(.headline)
                }
                .accessibilityLabel(Text("Settings button"))
            }
            .padding(.top, 30)
            
            /// Feedback
            HStack {
                Button(action: {
                    // TODO: make feedback page
                    Text("pressed give feedback button")
                }) {
                    Image(systemName: "envelope")
                        .imageScale(.large)
                        .foregroundColor(.black)
                    Text("Give Feedback")
                        .foregroundColor(.black)
                        .font(.headline)
                }
                .accessibilityLabel(Text("Give feedback button"))
            }
            .padding(.top, 30)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        MenuView()
    }
}
