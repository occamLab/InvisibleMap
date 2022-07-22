//
//  UserAccountView.swift
//  InvisibleMap
//
//  Created by occamlab on 7/19/22.
//  Copyright © 2022 Occam Lab. All rights reserved.
//

import SwiftUI
import FirebaseAuth

struct UserAccountView: View {
    @Binding var showUserAccView: Bool
    
    var body: some View {
        NavigationView {
           // if let currentUser = Auth.auth().currentUser {
            Text("User Account ID: \(String(describing: Auth.auth().currentUser?.uid))")
          //  }
            
            .navigationBarTitle(Text("Invisible Map Creator User Account Information"), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                self.showUserAccView = false
            }) {
                Text("Done").bold()
            })
        }
    }
}

