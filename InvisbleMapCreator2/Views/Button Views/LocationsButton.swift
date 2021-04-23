//
//  LocationsButton.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/14/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct LocationsButton: View {
    var body: some View {
        ZStack {
            HStack {
                Spacer()
                    .frame(width: 210)
                
                Button(action: {
                    //TODO: Manage locations button
                }){
                    Image(systemName: "line.horizontal.3")
                        .accessibility(label: Text("Manage Locations"))
                        .padding(20)
                }
                .frame(width: 80, height: 50, alignment: .trailing)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .foregroundColor(Color(UIColor.systemBackground))
                        .opacity(0.7))
            }
            
            Button(action: {
                //TODO: Save location button
            }){
                HStack {
                    Image(systemName: "plus")
                    Text("Add Location")
                }
            }
            .frame(width: 180, height: 50)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .foregroundColor(.green))
        }
    }
}

struct LocationsButton_Previews: PreviewProvider {
    static var previews: some View {
        LocationsButton()
    }
}
