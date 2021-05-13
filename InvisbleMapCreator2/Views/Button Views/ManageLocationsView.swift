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
    
    /*cell.locationTextLabel?.text = nodeList[indexPath.row].node.name!
    cell.locationTextLabel?.sizeToFit()
    cell.locationImageView?.image = nodeList[indexPath.row].picture
    //cell.textLabel?.text = "test"
    return cell*/
    
    var body: some View {
        NavigationView {
            List (recordGlobalState.nodeList) { node in
                HStack {
                    Image(uiImage: node.picture)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200, alignment: .center)
                        .clipped()
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
