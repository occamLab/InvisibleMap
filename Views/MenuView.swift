//
//  MenuView.swift
//  InvisibleMapCreator2
//
//  Created by Joyce Chung on 6/9/22.
//  Copyright © 2022 Occam Lab. All rights reserved.
//

import SwiftUI
import FirebaseAuth

struct MenuView: View {
    @State private var isShowingHelpView = false
    @State private var isShowingSettingsView = false
    @State private var isShowingFeedbackView = false
    @State private var isShowingUserAccView = false
    
    var body: some View {
        VStack(alignment: .leading) {
            
            /// Tutorials/Help
            HStack {
                Button(action: {
                    // TODO: add tutorials
                    isShowingHelpView = true
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
            .sheet(isPresented: $isShowingHelpView) {
                HelpView(showHelp: $isShowingHelpView)
            }
            
            
            /// Settings
            HStack {
                Button(action: {
                    // TODO: make settings
                    isShowingSettingsView = true
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
            .sheet(isPresented: $isShowingSettingsView) {
                SettingsView(showSettings: $isShowingSettingsView)
            }
            
            
            /// Feedback
            HStack {
                Button(action: {
                    // TODO: make feedback page
                    isShowingFeedbackView = true
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
            .sheet(isPresented: $isShowingFeedbackView) {
                FeedbackView(showFeedbackView: $isShowingFeedbackView)
            }
            
            /// User Account Information
            HStack {
                Button(action: {
                    isShowingUserAccView = true
                }) {
                    Image(systemName: "person.circle")
                        .imageScale(.large)
                        .foregroundColor(.black)
                    Text("User Account")
                        .foregroundColor(.black)
                        .font(.headline)
                }
                .accessibilityLabel(Text("User Account button"))
            }
            .padding(.top, 30)
            .sheet(isPresented: $isShowingUserAccView) {
                UserAccountView(showUserAccView: $isShowingUserAccView)
            }

            /// Sign out
            HStack {
                Button(action: {
                    do {
                        try! Auth.auth().signOut()
                    }
                }) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .imageScale(.large)
                        .foregroundColor(.black)
                    Text("Sign Out")
                        .foregroundColor(.black)
                        .font(.headline)
                }
                .accessibilityLabel(Text("Sign out button"))
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
