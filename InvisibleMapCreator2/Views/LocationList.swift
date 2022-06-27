//
//  LocationList.swift
//  InvisibleMapCreator2
//
//  Created by occamlab on 6/27/22.
//  Copyright © 2022 Occam Lab. All rights reserved.
//

import SwiftUI

struct LocationList: View {
    var mapName: String
    @Binding var showLocations: Bool
    
    var body: some View {
        NavigationView {
            List{
              //  ForEach(Array(map.waypointDictionary.keys), id: \.self) {
               //     location in Text("\(map.waypointDictionary[location]!.id)")
                //is there a way to access a map's waypointDictionary with it's name?
                Text("Locations of Interest in \(mapName):")
                Text("location 2")
                //}
            }
        }
    }
}


