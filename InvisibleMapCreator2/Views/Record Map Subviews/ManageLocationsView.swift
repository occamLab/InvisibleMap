//
//  ManageLocationsView.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 5/10/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct ManageLocationsView: View {
    @ObservedObject var recordGlobalState: RecordGlobalState
    @Binding var showLocations: Bool
    
    var body: some View {
        NavigationView {
            List (recordGlobalState.nodeList) { node in
                HStack {
                    Image(uiImage: node.picture)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipped()
                        .cornerRadius(8)
                    Text(node.node.name!)
                }
            }
            .navigationBarTitle(Text("Saved Locations"), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                self.showLocations = false
            }) {
                Text("Done").bold()
            })
        }
    }
}


struct ManageLocationsView_Previews: PreviewProvider {
    @StateObject static var recordGlobalState = RecordGlobalState()
    @State static var showLocations = false
    
    static var previews: some View {
        ManageLocationsView(recordGlobalState: recordGlobalState, showLocations: $showLocations)
    }
}
