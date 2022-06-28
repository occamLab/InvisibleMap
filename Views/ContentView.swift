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
        Auth.auth().addStateDidChangeListener { auth, user in
            self.objectWillChange.send()
        }
    }
}

struct ContentView: View {
    @ObservedObject var authListener = AuthListener()
    @ObservedObject var mapDatabase = FirebaseManager.createMapDatabase()
    @State var showMenu = false
    @State var searchText = ""
    @Environment(\.isPresented) private var isPresented
    
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
                                    NavigationLink(destination: SelectPathView(mapName: map.name).onAppear() {
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
                                        .frame(width: 200, height: 40)
                                        .foregroundColor(.blue)
                                        .background(
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(Color.blue, lineWidth: 1))
                                   
                                }
                            #endif
                            }
                            //if user presses burger menu bar, show the menu
                            if self.showMenu {
                                MenuView()
                                    .frame(width: geometry.size.width/2)
                                    .transition(.move(edge: .leading))
                                    .background(Color.white)
                            }
                        }
                        .gesture(drag)
                    }
                    .listStyle(PlainListStyle())
                #if IS_MAP_CREATOR
                    .navigationBarTitle("My Created Invisible Maps", displayMode: .inline)
                #else
                    .navigationBarTitle("Invisible Maps", displayMode: .inline)
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
                }
        
            //    .listStyle(PlainListStyle())
            #if IS_MAP_CREATOR
                .navigationTitle("My Created Invisible Maps")
            #else
                .navigationTitle("Invisible Maps")
            #endif
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

