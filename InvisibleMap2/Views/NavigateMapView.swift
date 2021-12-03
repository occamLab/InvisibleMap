//
//  NavigateMapView.swift
//  InvisibleMap2
//
//  Created by tad on 11/12/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI
import FirebaseAuth

struct ExitButton: View {
    @Environment(\.presentationMode) var mode: Binding<PresentationMode> // Tracks whether the RecordMap screen is being presented

    var body: some View {
        Button(action: {
            self.mode.wrappedValue.dismiss()
            InvisibleMapController.shared.process(event: .LeaveMapRequested) // Tells the state machine to cancel the map recording
        }){
            Image(systemName: "xmark")
                .accessibility(label: Text("Exit Navigation"))
        }
        .buttonStyle(RectangleButtonStyle())
    }
}

struct NavigateMapView: View {
    init() {
        print("currentUser is \(Auth.auth().currentUser!.uid)")
    }
    
    var body : some View {
        BaseNavigationView()
            // Toolbar buttons
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    ExitButton()
                }
            })
        .ignoresSafeArea(.keyboard)
    }
}

extension UINavigationController {
    override open func viewDidLoad() {
        super.viewDidLoad()
      
        // Creates a translucent toolbar
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithTransparentBackground()
        toolbarAppearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)
        UIToolbar.appearance().standardAppearance = toolbarAppearance
    }
}

struct NavigateMapView_Previews: PreviewProvider {
    static var previews: some View {
        NavigateMapView()
    }
}
