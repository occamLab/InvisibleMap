//  EditMapView.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/23/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct EditMapView: View {
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        // TODO: Determine what the edit map view should look like
        
        // location in this map button
        Button(action: {
            // TODO: put in list of locations in map
        }) {
            Text("View Locations in this Map")
                .frame(minWidth: 0, maxWidth: 300)
                .padding()
                .foregroundColor(.black)
                .background(Color.green)
                .cornerRadius(10)
                .font(.system(size: 18, weight: .bold))
                .padding(10)
                .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green, lineWidth: 4))
        }.padding()
        
        // upload map button
        Button(action: {
            // TODO: upload map to IM app
        }) {
            Text("Upload Map to Invisible Maps")
                .frame(minWidth: 0, maxWidth: 300)
                .padding()
                .foregroundColor(.black)
                .background(Color.orange)
                .cornerRadius(10)
                .font(.system(size: 18, weight: .bold))
                .padding(10)
                .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.orange, lineWidth: 4))
        }.padding()
        
        // delete map button
        Button(action: {
            // TODO: delete map from list and in cloud
            showingDeleteConfirmation = true
        }) {
            Text("Delete Map")
                .frame(minWidth: 0, maxWidth: 300)
                .padding()
                .foregroundColor(.white)
                .background(Color.red)
                .cornerRadius(10)
                .font(.system(size: 18, weight: .bold))
                .padding(10)
                .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red, lineWidth: 4))
        }.padding()
        // delete confirmation alert popup message when delete route button is pressed
            .alert(isPresented: $showingDeleteConfirmation) {
                Alert(
                    title: Text("Are you sure?"),
                    primaryButton: .destructive(Text("Delete")) {
                        //TODO: delete map from list and IM app 
                    },
                    secondaryButton: .cancel()
                )
            }
        
        // Share map button
        Button(action: {
            // TODO: share map
        }) {
            Text("Share Map")
                .frame(minWidth: 0, maxWidth: 300)
                .padding()
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(10)
                .font(.system(size: 18, weight: .bold))
                .padding(10)
                .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue, lineWidth: 4))
        }.padding()
    }
}

struct EditMapView_Previews: PreviewProvider {
    static var previews: some View {
        EditMapView()
    }
}
