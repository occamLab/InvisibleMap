//
//  LocationListView.swift
//  InvisibleMapCreator2
//
//  Created by Joyce Chung on 6/27/22.
//  Copyright © 2022 Occam Lab. All rights reserved.
//

import SwiftUI

struct LocationListView: View {
    var mapName: String
    var mapFileName: String
    @Binding var showLocations: Bool
    @ObservedObject var mapRecorder = InvisibleMapCreatorController.shared.mapRecorder
    
    var body: some View {
        NavigationView {
            if mapRecorder.map != nil {
                List{
                    ForEach(Array(mapRecorder.map.waypointDictionary.keys), id: \.self) {
                        location in Text("\(mapRecorder.map.waypointDictionary[location]!.id)")
                    }
                }
             
                .navigationBarTitle(Text("Saved Locations for \(mapName)"), displayMode: .inline)
                .navigationBarItems(trailing: Button(action: {
                    self.showLocations = false
                }) {
                    Text("Done").bold()
                })
            }
        }
    }
}
    
