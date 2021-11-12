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
    
    var body: some View {
        if Auth.auth().currentUser == nil {
            AppleSignInControllerRepresentable()
        }
        else {
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
                    #if IS_MAP_CREATOR
                        // New map button
                        NavigationLink(
                            destination: RecordMapView()
                        ) {
                            Text("New Map")
                                .frame(width: 200, height: 40)
                                .foregroundColor(.blue)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.blue, lineWidth: 1))
                        }
                    #endif
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
                    .accessibilityLabel(Text("Settings"))
                )
            }
            .listStyle(PlainListStyle())
            .navigationTitle("All Maps")
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

