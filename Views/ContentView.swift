//
//  ContentView.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/5/21.
//

import SwiftUI
import Firebase
import FirebaseAuth

class AuthListener: ObservableObject {
    init() {
        FirebaseApp.configure()
        print("Firebase configured")
        Auth.auth().addStateDidChangeListener { auth, user in
            self.objectWillChange.send()
        print("auth listener listened")
        }
        print("auth listener created")
    }
}

struct ContentView: View {
    //@Published var signInState = "signed out"
    @StateObject var authListener = AuthListener()
    @StateObject var mapDatabase = FirebaseManager.createMapDatabase()
    @State var showMenu = false
    @State var searchText = ""
    @Environment(\.isPresented) private var isPresented
    #if !IS_MAP_CREATOR
 //   var backBarButtonItem: UIBarButtonItem? { get set }
    #endif
    
    var body: some View {
        // if signed out
        if Auth.auth().currentUser == nil {
            // sign in
            AppleSignInControllerRepresentable()
                .onReceive(authListener.objectWillChange) {
                    // update mapDatabase after authListener changes
                    mapDatabase.updateMapDatabase()
                    print("received auth alt \(Auth.auth().currentUser?.uid)")
                }
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
                            SearchBar(text: $searchText)
                                .padding()
                            // filtered maps array for search bar feature
                            let filteredMaps = self.mapDatabase.mapData.filter({ (map: MapData) -> Bool in
                                return map.name.localizedCaseInsensitiveContains(searchText) || searchText == "" })
                            
                            // Populate list view with data from firebase as the app is loaded
                            List {
                                ForEach(filteredMaps, id: \.image) { map in
                                    #if IS_MAP_CREATOR
                                    NavigationLink(
                                        destination: EditMapView(map: map)
                                    ) {
                                        HStack {
                                            Image(uiImage: map.image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipped()
                                                .cornerRadius(8)
                                            Text(map.name)
                                        }
                                    }
                                    #else
                                    NavigationLink(destination: SelectPathView(mapName: map.name, mapFileName: map.file).onAppear() {
                                        InvisibleMapController.shared.process(event: .MapSelected(mapFileName: map.file))
                                    })
                                    {
                                        HStack {
                                            Image(uiImage: map.image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipped()
                                                .cornerRadius(8)
                                            Text(map.name)
                                        }
                                    }
                                    #endif
                                }
                            }
                            Divider()
                            #if IS_MAP_CREATOR
                                // Create new map button
                                NavigationLink(
                                    destination: RecordMapView()
                                ) {
                                    Text("Create New Map")
                                        .fontWeight(.heavy)
                                        .frame(width: 250, height: 50)
                                        .foregroundColor(.blue)
                                        .background(
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 15)
                                                    .foregroundColor(Color(UIColor.systemBackground))
                                                RoundedRectangle(cornerRadius: 15)
                                                    .stroke(Color.blue, lineWidth: 2)
                                            })
                                   
                                }
                            #endif
                            }
                            //if user presses burger menu bar, show the menu
                            if self.showMenu {
                                MenuView()
                                    .frame(width: geometry.size.width/2)
                                    .transition(.move(edge: .leading))
                                    .background(Color(UIColor.systemBackground))
                            }
                        }
                        .gesture(drag)
                    }
                    .listStyle(PlainListStyle())
                #if IS_MAP_CREATOR
                    .navigationBarTitle("Invisible Map Creator Home", displayMode: .inline)
                #else
                    .navigationBarTitle("Invisible Map Home", displayMode: .inline)
                #endif
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
                }.onChange(of: isPresented) { isPresented in
                    print("isPresented \(isPresented)")
                    if isPresented {
                        // Do something when first presented.
                    }
                }/*.onReceive(authListener.objectWillChange) {
                  // if user has already signed in: updates mapDatabase again so populates map list twice 
                    print("again")
                    mapDatabase.updateMapDatabase()
                }*/
        
            //    .listStyle(PlainListStyle())
            #if IS_MAP_CREATOR
                .navigationTitle("My Created Invisible Maps")
            #else
                .navigationTitle("Invisible Maps")
            #endif
               
        }
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


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
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

