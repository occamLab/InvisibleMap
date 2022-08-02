//
//  SelectPathView.swift
//  InvisibleMap2
//
//  Created by occamlab on 11/30/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct SelectPathView: View {
    @ObservedObject var mapNavigator = InvisibleMapController.shared.mapNavigator
    var mapName: String
    var mapFileName: String
    
    init(mapName: String, mapFileName: String) {
        self.mapName = mapName
        self.mapFileName = mapFileName
        print("intitializing select path view...")
    }
    
    var body: some View {
        NavigationView {
            if let map = mapNavigator.map {
                VStack {
                    Text("Map Name: \(mapName)")
                        .font(.title)
                        .bold()
                    Spacer()
                    Text("Select a location of interest to navigate to: ")
                        .font(.title2)
                    // populate list of saved locations of interest of selected map
                    List {
                        Text("Saved Locations of Interests: ")
                        ForEach(Array(map.waypointDictionary.keys), id: \.self) { location in
                            // location list where each location navigates to navigation camera screen to start navigating to that selected location
                            NavigationLink(destination: NavigateMapView(mapFileName: mapFileName).onAppear() {
                                InvisibleMapController.shared.process(event: .PathSelected(locationType: "waypoint", Id: location))
                            }) {
                                Text("\(map.waypointDictionary[location]!.id)")
                            }
                        }
                    }
                    // populate list of tag locations of selected map
                    List {
                        Text("Tag Locations: ")
                        ForEach(Array(map.tagDictionary.keys), id: \.self) { location in
                            NavigationLink(destination: NavigateMapView(mapFileName: mapFileName).onAppear() {
                                InvisibleMapController.shared.process(event: .PathSelected(locationType: "tag", Id: location))
                            }) {
                                Text("\(location)")
                            }
                            .navigationBarBackButtonHidden(true)
                        }
                    }
                }
            }
        }.onDisappear() {
            InvisibleMapController.shared.process(event: .DismissPathRequested)  // when select path view is dismissed this event is called that sets the app back to the state it was before the select path view state
        }
    }
}

/*
struct SelectPathView_Previews: PreviewProvider {
    static var previews: some View {
        SelectPathView()
    }
} */
