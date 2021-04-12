//
//  SideMenuView.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/5/21.
//

import SwiftUI

struct SideMenuView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(
                    destination: PrintTagsView()
                ) {
                    SideMenuOptionView(viewModel: .printTags)
                }
                NavigationLink(
                    destination: ManageMapsView()
                ) {
                    SideMenuOptionView(viewModel: .manageMaps)
                }
                NavigationLink(
                    destination: SettingsView()
                ) {
                    SideMenuOptionView(viewModel: .settings)
                }
                NavigationLink(
                    destination: VideoWalkthroughView()
                ) {
                    SideMenuOptionView(viewModel: .videoWalkthrough)
                }
                NavigationLink(
                    destination: GiveFeedbackView()
                ) {
                    SideMenuOptionView(viewModel: .giveFeedback)
                }
            }
            .navigationTitle("Menu")
        }
    }
}

struct SideMenuView_Previews: PreviewProvider {
    static var previews: some View {
        SideMenuView()
    }
}
