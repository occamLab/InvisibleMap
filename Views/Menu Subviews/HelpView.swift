//
//  HelpView.swift
//  InvisibleMap
//
//  Created by Joyce Chung on 7/3/22.
//  Copyright © 2022 Occam Lab. All rights reserved.
//

import SwiftUI

struct HelpView: View {
    @Binding var showHelp: Bool
    @State private var isAppInfoExpanded = false
    @State private var isHowToCreateExpanded = false
    
    var body: some View {
        NavigationView {
            List {
                DisclosureGroup("App Information", isExpanded: $isAppInfoExpanded) {
                    Text("The Invisible Map Creator allows users to create maps of indoor spaces with user-defined points of interests (ex. restrooms and exits in a building) using April tags. The created maps will then be uploaded to a private databse where it is processed and uploaded to the Invisible Map app. \n\nThe Invisible Map app automatically creates paths from the user's current location, which is determined by scanning any April tag in the area, to any April tag or point of interest on a given map.")
                }
                
                DisclosureGroup("How to Create a Map", isExpanded: $isHowToCreateExpanded) {
                    Text("In an indoor space, put up April tags on the wall roughly equidistant from each other. Next, create a map by marking one April tag at a time as you walk the route you want to create on the map. As you walk the route, you may drop points of interest on the map by adding locations at any time. Once you are done walking the route, we recommend walking the route backwards and marking the previously marked tags a second time in the opposite direction. Finally, you may save and name the map. After saving the map, the map should be automatically uploaded to the Invisible Map app. \n\nNOTE: It may take a few minutes for the map to successfully upload on the Invisible Map Creator and Invisible Map apps.")
                }
            }
                .navigationBarTitle(Text("Invisible Map Creator Help"), displayMode: .inline)
                .navigationBarItems(trailing: Button(action: {
                    self.showHelp = false
                }) {
                    Text("Done").bold()
                })
        }
    }
}
