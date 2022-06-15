//
//  ContentView.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/5/21.
//

import SwiftUI
import Firebase
import FirebaseAuth

class MapDatabase: ObservableObject {
    @Published var maps: [String] = []
    @Published var images: [UIImage] = []
    @Published var files: [String] = []
    var mapsRef: DatabaseReference!
    var storageRef: StorageReference!
    
    init() {
        var userMapsPath = "maps/"
        if Auth.auth().currentUser != nil {
            userMapsPath = userMapsPath + String(Auth.auth().currentUser!.uid)
        }
        mapsRef = Database.database(url: "https://invisible-map-sandbox.firebaseio.com/").reference(withPath: userMapsPath)
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

class AuthListener: ObservableObject {
    init() {
        FirebaseApp.configure()
        Auth.auth().addStateDidChangeListener { auth, user in
            self.objectWillChange.send()
        }
    }
}


struct ContentView: View {
    @ObservedObject var authListener = AuthListener()
    @ObservedObject var mapDatabase = MapDatabase()
    @State var showMenu = false
    @State private var searchText = ""
    
    /// function to delete a map from the list of maps
    func deleteMap(at offsets: IndexSet) {
        mapDatabase.maps.remove(atOffsets: offsets)
    }
    
    var body: some View {
        
        if Auth.auth().currentUser == nil {
            AppleSignInControllerRepresentable()
        }
        else {
            //menu drag in, drag out feature
            let drag = DragGesture()
                .onEnded {
                    if $0.translation.width < -100 {
                        withAnimation {
                            self.showMenu = false
                        }
                    }
                }
            
            NavigationView {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        VStack {
                            // All maps list
                            Text("My Invisible Maps")
                                .font(.largeTitle)
                                .bold()
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
                                //slide to delete
                                .onDelete(perform: deleteMap)
                            }
                            
                            Divider()
                            // New map button
                            NavigationLink(
                                destination: RecordMapView()
                            ) {
                                Text("Create New Map")
                                    .frame(width: 200, height: 40)
                                    .foregroundColor(.blue)
                                    .background(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.blue, lineWidth: 1))
                            }
                        } //VStack
                        
                        //if user presses burger menu bar, show the menu
                        if self.showMenu {
                            MenuView()
                                .frame(width: geometry.size.width/2)
                                .transition(.move(edge: .leading))
                                .background(Color.white)
                        }
                    } //ZStack
                    .gesture(drag)
                } //geometryreader
                .listStyle(PlainListStyle())
            //    .navigationBarTitle("My Invisible Maps", displayMode: .inline)
                .navigationBarItems(leading:
                    //burger menu bar button to drag in/out menu from top, left corner
                    Button(action: {
                        withAnimation {
                            self.showMenu.toggle()
                        }
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .imageScale(.large)
                            .foregroundColor(.black)
                    }
                    .accessibilityLabel(Text("Menu Bar"))
                )
            }
    
        //    .listStyle(PlainListStyle())
         //   .navigationTitle("All Maps")
//            .navigationBarItems(trailing:
//                Button(action: {
//                    // TODO: Build settings menu
//                }) {
//                    Image(systemName: "gearshape").imageScale(.large)
//                        .foregroundColor(.black)
//                }
//                .accessibilityLabel(Text("Settings"))
//            )
        }
        
    }
    
}



struct AppleSignInControllerRepresentable: UIViewControllerRepresentable {
    typealias UIViewControllerType = AppleSignInController
    
    func makeUIViewController(context: Context) -> AppleSignInController {
        print("Created AppleSignInController")
        return AppleSignInController()
    }
    func updateUIViewController(_ uiViewController: AppleSignInController, context: Context) {
        return
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

