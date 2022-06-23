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
            // user id
            userMapsPath = userMapsPath + String(Auth.auth().currentUser!.uid)
        }
        
        // reference to all maps for the user under sandbox in firebase
        mapsRef = Database.database(url: "https://invisible-map-sandbox.firebaseio.com/").reference(withPath: userMapsPath)
        storageRef = Storage.storage().reference()
        
        // Tracks any addition, change, or removal to the map database
        
        // Every time the app is opened process all saved maps
        self.mapsRef.observe(.childAdded) { (snapshot) -> Void in
            self.processMap(key: snapshot.key, values: snapshot.value as! [String: Any])
        }
        // Every time a map is changed process all saved maps
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
        // prcoess map file and its image and update the map database 
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

// write extensions to a class if you want to add something apart from previously written code; also this is a good way to have this extension conform only to the MapController protocol (in AppController.swift)
extension MapDatabase: MapsController {
    func deleteMap(mapID: String) {
        // get index of map in maps array (same index in images and files array)
        if let mapIndex = maps.firstIndex(of: mapID) {
            // remove map and its info from map list in Home Page by removing map from map array
            maps.remove(at: mapIndex)
            images.remove(at: mapIndex)
            files.remove(at: mapIndex)
            // remove map from Firebase
            mapsRef.child(mapID).removeValue()
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
    @ObservedObject var mapDatabase = AppController.shared.mapsController
    @State var showMenu = false
    @State var searchText = ""
    
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
                        //    Text("My Invisible Maps")
                        //        .font(.largeTitle)
                        //        .bold()
                            
                            SearchBar(text: $searchText)
                                .padding()
                            
                            // Populate list view with data from firebase as the app is loaded; this array of map list should be updated each time the app is opened or when map is deleted or changed from the observable object mapdatabase that processes the current maps
                            let mapArray = Array(zip(self.mapDatabase.images, self.mapDatabase.maps))
                            let filteredMaps = mapArray.filter({ (map: (UIImage, String)) -> Bool in
                                return map.1.localizedCaseInsensitiveContains(searchText) || searchText == "" })
                            List {
                                ForEach(filteredMaps, id: \.0) {map in
                                    
                                    NavigationLink(
                                        destination: EditMapView(map: map.1)
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
                .navigationBarTitle("My Invisible Maps", displayMode: .inline)
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
            .navigationTitle("My Invisible Maps")
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


/// search bar feature on Main Screen
struct SearchBar: View {
    @Binding var text: String
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            TextField("Search ...", text: $text)
                            .padding(7)
                            .padding(.horizontal, 25)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.gray)
                                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 8)
                             
                                    if isEditing {
                                        Button(action: {
                                            self.text = ""
                                        }) {
                                            Image(systemName: "multiply.circle.fill")
                                                .foregroundColor(.gray)
                                                .padding(.trailing, 8)
                                        }
                                    }
                                }
                            )

                            .padding(.horizontal, 10)
                            .onTapGesture {
                                self.isEditing = true
                            }
             
                        if isEditing {
                            Button(action: {
                                self.isEditing = false
                                self.text = ""
                                // Dismiss the keyboard
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }) {
                                Text("Cancel")
                            }
                            .padding(.trailing, 10)
                            .transition(.move(edge: .trailing))
                            .animation(.default)
                        }
        }
    }
}

/*
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
*/
