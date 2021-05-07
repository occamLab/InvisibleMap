//
//  ContentView.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/5/21.
//

import SwiftUI

struct ContentView: View {
    @State private var showRecordingUI = false
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    NavigationLink(
                        destination: EditMapView()
                    ) {
                        MapRow(mapName: "Map Name")
                    }
                    NavigationLink(
                        destination: EditMapView()
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
                AppController.shared.startRecordingRequested() // Tells the state machine to start the map recording
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

