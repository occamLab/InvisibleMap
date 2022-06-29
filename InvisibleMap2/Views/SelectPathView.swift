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
    public var arViewer: ARView?
    var mapName: String
    var mapFileName: String
    
    var body: some View {
        NavigationView {
            if mapNavigator.map != nil {
                VStack {
                    Text("Map Name: \(mapName)")
                        .font(.title)
                        .bold()
                    Spacer()
                    Text("Select a location of interest to navigate to: ")
                        .font(.title2)
                    // populate list of tag locations of selected map
                    List {
                        Text("Tag Locations: ")
                        ForEach(Array(mapNavigator.map.tagDictionary.keys), id: \.self) { location in
                            NavigationLink(destination: NavigateMapView(mapFileName: mapFileName).onAppear() {
                                InvisibleMapController.shared.process(event: .PathSelected(locationType: "tag", Id: location))
                            }) {
                                Text("\(location)")
                            }
                        }
                    }
                    // populate list of saved locations of interest of selected map
                    
                    List {
                        Text("Saved Locations of Interests: ")
                        ForEach(Array(mapNavigator.map.waypointDictionary.keys), id: \.self) { location in
                            // location list where each location navigates to navigation camera screen to start navigating to that selected location
                            NavigationLink(destination: NavigateMapView(mapFileName: mapFileName).onAppear() {
                                InvisibleMapController.shared.process(event: .PathSelected(locationType: "waypoint", Id: location))
                            }) {
                                Text("\(mapNavigator.map.waypointDictionary[location]!.id)")
                            }
                        }
                    }
                }
            }
        }.onDisappear() {
            InvisibleMapController.shared.process(event: .DismissPathRequested)  // when select path view is dismissed this event is called that sets the app back to the state it was before the select path view state
        }
      /*  .onAppear() {
            self.arViewer?.endSound()
        } */
    }
}

/*
struct SelectPathView_Previews: PreviewProvider {
    static var previews: some View {
        SelectPathView()
    }
} */
