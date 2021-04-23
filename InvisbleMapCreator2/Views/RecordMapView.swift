//
//  RecordMapView.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/14/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

// ARView struct
struct NavigationIndicator: UIViewControllerRepresentable {
   typealias UIViewControllerType = ARView
   func makeUIViewController(context: Context) -> ARView {
      return ARView()
   }
   func updateUIViewController(_ uiViewController:
   NavigationIndicator.UIViewControllerType, context:
   UIViewControllerRepresentableContext<NavigationIndicator>) { }
}

struct RecordMapView: View {
    var body : some View {
        ZStack {
            NavigationIndicator().edgesIgnoringSafeArea(.all)
                .navigationBarHidden(true)
                .navigationBarBackButtonHidden(true)
                .toolbar(content: {
                    ToolbarItem(placement: .bottomBar) {
                        HStack {
                            AddLocationButton()
                            ManageLocationsButton()
                        }
                    }
                })
            VStack {
                HStack {
                    ExitButton()
                    Spacer()
                    SaveButton()
                }
                Spacer()
            }
            .padding(20)
        }
    }
}

extension UINavigationController {
    override open func viewDidLoad() {
        super.viewDidLoad()
      
        //Create translucent toolbar
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithTransparentBackground()
        toolbarAppearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.5)
        UIToolbar.appearance().standardAppearance = toolbarAppearance
    }
}

struct RecordMapView_Previews: PreviewProvider {
    static var previews: some View {
        RecordMapView()
    }
}
