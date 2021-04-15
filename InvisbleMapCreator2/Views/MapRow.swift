//
//  MapRow.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/13/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct MapRow: View {
    var mapName: String
    
    var body: some View {
        VStack {
            HStack {
                Text(mapName)
                Spacer()
                Button(action: {
                    //TODO: Direct to edit screen
                }){
                    Text("Edit")
                }
            }
            
            Rectangle()
                .fill(Color.gray)
                .frame(height: 150)
        }
        .padding(20)
    }
}

struct MapRow_Previews: PreviewProvider {
    static var previews: some View {
        MapRow(mapName: "Map Name")
    }
}
