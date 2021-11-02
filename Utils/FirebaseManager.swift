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
    static func createMap(from mapFileName: String) -> Map {
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
