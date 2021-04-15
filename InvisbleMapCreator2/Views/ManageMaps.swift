//
//  ManageMaps.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/14/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct ManageMaps: View {
    @State private var showRecordingUI = false

    var body: some View {
        NavigationView {
            VStack {
                List {
                    NavigationLink(
                        destination: PrintTagsView()
                    ) {
                        MapRow(mapName: "Map Name")
                    }
                    NavigationLink(
                        destination: PrintTagsView()
                    ) {
                        MapRow(mapName: "Map Name")
                    }
                }
                NavigationLink(
                    destination: RecordMapView(),
                    isActive: $showRecordingUI
                ) {
                    Text("New Map")

                }
            }
            .navigationTitle("All Maps")
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                showRecordingUI = true
            }
        }
    }
}


struct ManageMaps_Previews: PreviewProvider {
    static var previews: some View {
        ManageMaps()
    }
}
