//
//  LocationListView.swift
//  InvisibleMapCreator2
//
//  Created by occamlab on 6/27/22.
//  Copyright © 2022 Occam Lab. All rights reserved.
//

import SwiftUI

struct LocationListView: View {
    var mapName: String
    @Binding var showLocations: Bool
 //   var map: Map!
 //   @ObservedObject var recordGlobalState: RecordGlobalState
    
    var body: some View {
        NavigationView {
            List{
             //   ForEach(Array(map.waypointDictionary.keys), id: \.self) {
             //       location in Text("\(map.waypointDictionary[location]!.id)")
                //is there a way to access a map's waypointDictionary with it's name?
                Text("In progress: This view does not work yet. \nYou can go to the Invisible Maps app to see the locations of interests")
              //  }
            }
          /*  List (recordGlobalState.nodeList) { node in
                HStack {
                    Image(uiImage: node.picture)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipped()
                        .cornerRadius(8)
                    Text(node.node.name!)
                }
            }*/
            .navigationBarTitle(Text("Saved Locations for \(mapName)"), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                self.showLocations = false
            }) {
                Text("Done").bold()
            })
        }
    }
}
