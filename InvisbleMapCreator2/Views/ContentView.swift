//
//  ContentView.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/5/21.
//

import SwiftUI
import Firebase

class MapDatabase: ObservableObject {
    @Published var maps: [String] = []
    @Published var images: [UIImage] = []
    @Published var files: [String] = []
    var mapsRef: DatabaseReference!
    var storageRef: StorageReference!
    
    init() {
        FirebaseApp.configure()
        mapsRef = Database.database(url: "https://invisible-map-sandbox.firebaseio.com/").reference(withPath: "maps")
        storageRef = Storage.storage().reference()
        
        // Tracks any addition, change, or removal to the map database
        self.mapsRef.observe(.childAdded) { (snapshot) -> Void in
            self.processMap(key: snapshot.key, values: snapshot.value as! [String: Any])
        }
        self.mapsRef.observe(.childChanged) { (snapshot) -> Void in
            self.processMap(key: snapshot.key, values: snapshot.value as! [String: Any])
        }
        self.mapsRef.observe(.childRemoved) { (snapshot) -> Void in
            if let existingMapIndex = self.maps.firstIndex(of: snapshot.key) {
                self.maps.remove(at: existingMapIndex)
                self.images.remove(at: existingMapIndex)
                self.files.remove(at: existingMapIndex)
            }
        }
    }
    
    func processMap(key: String, values: [String: Any]) {
        // Only include in the list if it is processed
        if let processedMapFile = values["map_file"] as? String {
            // TODO: pick a sensible default image
            let imageRef = storageRef.child((values["image"] as? String) ?? "olin_library.jpg")
            imageRef.getData(maxSize: 10*1024*1024) { imageData, error in
                if let error = error {
                    print(error.localizedDescription)
                    // Error occurred
                } else {
                    if let data = imageData {
                        self.images.append(UIImage(data: data)!)
                        self.files.append(processedMapFile)
                        self.maps.append(key)
                    }
                }
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var mapDatabase = MapDatabase()
    @State private var showRecordingUI = false
    
    var body: some View {
        NavigationView {
            VStack {
                // All maps list
                List {
                    // Populate list view with data from firebase as the app is loaded
                    ForEach(Array(zip(self.mapDatabase.images, self.mapDatabase.maps)), id: \.0) { map in
                        NavigationLink(
                            destination: EditMapView() // TODO: Determine what each map should navigate to
                        ) {
                            HStack {
                                Image(uiImage: map.0)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                                Text(map.1)
                            }
                        }
                    }
                }
                Divider()
                // New map button
                NavigationLink(
                    destination: RecordMapView(),
                    isActive: $showRecordingUI
                ) {
                    Text("New Map")
                        .frame(width: 200, height: 40)
                        .foregroundColor(.blue)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.blue, lineWidth: 1))
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("All Maps")
            .navigationBarItems(trailing:
                Button(action: {
                    // TODO: Build settings menu 
                }) {
                    Image(systemName: "gearshape").imageScale(.large)
                        .foregroundColor(.black)
                }
            )
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

