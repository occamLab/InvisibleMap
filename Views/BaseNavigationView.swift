//
//  BaseNavigationView.swift
//  InvisibleMap
//
//  Created by Allison Li and Ben Morris on 11/12/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

// Stores the ARView
struct NavigationIndicator: UIViewControllerRepresentable {
   typealias UIViewControllerType = ARView
    func makeUIViewController(context: Context) -> ARView {
        return ARView()
   }
   func updateUIViewController(_ uiViewController:
   NavigationIndicator.UIViewControllerType, context:
   UIViewControllerRepresentableContext<NavigationIndicator>) { }
}

struct BaseNavigationView: View {
    var body : some View {
        NavigationIndicator().edgesIgnoringSafeArea(.all)
            // Hides the default navigation bar so that we can replace it with custom exit and save buttons
            // .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
    }
}

struct BaseNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        BaseNavigationView()
    }
}
