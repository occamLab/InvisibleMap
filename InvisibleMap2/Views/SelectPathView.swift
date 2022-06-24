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
                    // TODO: Instead of tag locations, this should be a list of POI/saved locations on the map 
                   /* List {
                        ForEach(Array(mapNavigator.map.tagDictionary.keys), id: \.self) { location in
                            NavigationLink(destination: NavigateMapView().onAppear() {
                                InvisibleMapController.shared.process(event: .PathSelected(tagId: location))
                            }) {
                                Text("\(location)")
                            }
                        }
                    } */
                    List {
                        ForEach(Array(mapNavigator.map.waypointDictionary.keys), id: \.self) { location in
                            // location list where each location navigates to navigation camera screen to start navigating to that selected location
                            NavigationLink(destination: NavigateMapView().onAppear() {
                                //InvisibleMapController.shared.process(event: .PathSelected(tagId: location))
                            }) {
                                Text("\(mapNavigator.map.waypointDictionary[location]!.id)")
                            }
                        }
                    }
                }
            }
        }
    }
}

/*
struct SelectPathView_Previews: PreviewProvider {
    static var previews: some View {
        SelectPathView()
    }
} */
