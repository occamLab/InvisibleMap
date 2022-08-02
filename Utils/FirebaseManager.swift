//
//  FirebaseManager.swift
//  InvisibleMap
//
//  Created by Allison Li and Ben Morris on 10/19/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import Foundation
import Firebase
import FirebaseDatabase
import FirebaseStorage

class FirebaseManager {
    static var storageRef: StorageReference = Storage.storage().reference()
    
    /// Downloads the selected map from firebase
    static func createMap(from mapFileName: String, completionHandler: @escaping (Map)->()) {
        let mapRef = storageRef.child(mapFileName)
        var map: Map?
        print("creating map")
        mapRef.getData(maxSize: 10 * 1024 * 1024) { mapData, error in
            if let error = error {
                print(error.localizedDescription)
                // Error occurred
            } else {
                if let mapData = mapData {
                    map = Map(from: mapData)

                    completionHandler(map!)
                }
            }
        }
    }
    
    static func createMapDatabase() -> MapDatabase {
        var userMapsPath = "maps/"
        if Auth.auth().currentUser != nil {
            userMapsPath = userMapsPath + String(Auth.auth().currentUser!.uid)
            print("user id - \(String(Auth.auth().currentUser!.uid))")
        }
        let mapsRef = Database.database(url: "https://invisible-map-sandbox.firebaseio.com/").reference(withPath: userMapsPath)
        return MapDatabase(from: storageRef, with: mapsRef)
    }
}

class MapDatabase: ObservableObject {
    @Published var mapData: [MapData] = []
    @Published var maps: [String] = []
    @Published var images: [UIImage] = []
    @Published var files: [String] = []
    var mapsRef: DatabaseReference
    var storageRef: StorageReference
    
    init(from storageRef: StorageReference, with mapsRef: DatabaseReference) {
        self.mapsRef = mapsRef
        self.storageRef = storageRef
        populateMap()
    }
    
    func populateMap() {
        mapData = []
        maps = []
        images = []
        files = []
        
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
                self.mapData.remove(at: existingMapIndex)
            }
        }
    }
    
    func updateMapDatabase() {
        // TODO: repopulate mapsRef, storageRef, files, etc., etc.
        var userMapsPath = "maps/"
        if Auth.auth().currentUser != nil {
            userMapsPath = userMapsPath + String(Auth.auth().currentUser!.uid)
            print("user id - \(String(Auth.auth().currentUser!.uid))")
        }
        // TODO: maybe reduce copy paste code from FirebaseManager
        mapsRef = Database.database(url: "https://invisible-map-sandbox.firebaseio.com/").reference(withPath: userMapsPath)
        populateMap()
    }
    
    func processMap(key: String, values: [String: Any]) {
        // Only include in the list if it is processed
        if let processedMapFile = values["map_file"] as? String {
            // TODO: pick a sensible default image
            print("donwload image")
            let imageRef = storageRef.child((values["image"] as? String) ?? "olin_library.jpg")
            imageRef.getData(maxSize: 10*1024*1024) { imageData, error in
                if let error = error {
                    print(error.localizedDescription)
                    // Error occurred
                } else {
                    if let data = imageData {
                        let image = UIImage(data: data)!
                        self.images.append(image)
                        self.files.append(processedMapFile)
                        self.maps.append(key)
                        self.mapData.append(MapData(name: key, image: image, file: processedMapFile))
                    }
                }
            }
        }
    }
}

#if IS_MAP_CREATOR
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
#endif


// a map object
struct MapData {
    var name: String
    var image: UIImage
    var file: String
    
    init(name: String, image: UIImage, file: String) {
        self.name = name
        self.image = image
        self.file = file
    }
}
