//
//  SettingsView.swift
//  InvisibleMap
//
//  Created by Joyce Chung on 7/3/22.
//  Copyright © 2022 Occam Lab. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    @Binding var showSettings: Bool
    
    var body: some View {
        NavigationView {
            Text("Settings View in progress. \n\nFor co-designers: Please provide us with any ideas you have for the settings menu. What features of this app do you think should have option controls in the Settings menu?")
            
            .navigationBarTitle(Text("Invisible Map Creator Settings"), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                self.showSettings = false
            }) {
                Text("Done").bold()
            })
        }
    }
}


