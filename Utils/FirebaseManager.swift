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
    
    var storageRef: StorageReference!
    var mapFileName: String = ""
    
    /// Downloads the selected map from firebase
    func createMap() -> Map {
        let storage = Storage.storage()
        storageRef = storage.reference()
        let mapRef = storageRef.child(mapFileName)
        var map: Map?
        mapRef.getData(maxSize: 10 * 1024 * 1024) { mapData, error in
            if let error = error {
                print(error.localizedDescription)
                // Error occurred
            } else {
                if mapData != nil {
                    map = Map(from: mapData!)!
                }
            }
        }
        return map!
    }
}
