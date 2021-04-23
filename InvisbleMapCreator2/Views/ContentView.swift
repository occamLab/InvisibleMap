//
//  ContentView.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/5/21.
//

import SwiftUI

/*// All the view types that will exist as a popover over the main screen
enum PopoverViewType {
    case optionsMenu
    case recordMap
}

// Announce any changes that occur to the popover UI
class PopoverViewTypeWrapper: ObservableObject {
    @Published var popoverUI: PopoverViewType
    
    public init() {
        popoverUI = .recordMap
    }
}*/

// Store view wrappers and state variables outside of view struct
class GlobalState {
    public static var shared = GlobalState()
    //var popoverViewWrapper = PopoverViewTypeWrapper()
    
    private init() {

    }
}

struct ContentView: View {
    //@ObservedObject var popoverViewWrapper = GlobalState.shared.popoverViewWrapper // Track changes to popover UI
    @State private var showRecordingUI = false
    
    init() {
        AppController.shared.contentViewer = self
    }
    
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
                AppController.shared.startRecordingRequested() // Request start recording in state machine
            }
        }
    }
}

extension ContentView: ContentViewController {
    func displayRecordingUI() {
    }
    
    func displayMainScreen() {
    }
    
    func displayOptionsMenu() {
        //popoverViewWrapper.popoverUI = .optionsMenu
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

