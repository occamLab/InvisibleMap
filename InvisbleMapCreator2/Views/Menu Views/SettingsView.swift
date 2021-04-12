//
//  SettingsView.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/8/21.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack {
            NavigationView {
                Form {
                    Section(header: Text("General Options")) {
                        Text("Account")
                        Text("Length of Tag Edge")
                    }
                    
                    Section(header: Text("Next Settings")) {
                        Text("Settings Go Here")
                    }
                }
                .navigationBarTitle("Settings")
            }
            Spacer()
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
