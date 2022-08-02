//
//  ChooseMapViewController.swift
//  InvisibleMap
//
//  Created by djconnolly27 on 8/8/18.
//  Copyright © 2018 Occam Lab. All rights reserved.
//

import Foundation
import Firebase
import FirebaseAuth

/// A View Controller for handling map selection
class ChooseMapViewController: UITableViewController {
    
    
    //MARK: Properties
    var maps: [String] = []
    var images: [UIImage] = []
    var files: [String] = []
    var selectedRow = 0
    var mapsRef: DatabaseReference!
    var storageRef: StorageReference!
        
    /// Populates the table view with data from firebase as the app is loaded
    override func viewDidLoad() {
        super.viewDidLoad()
        storageRef = Storage.storage().reference()
        mapsRef = Database.database(url: "https://invisible-map-sandbox.firebaseio.com/").reference(withPath: "maps")
        mapsRef.observe(.childAdded) { (snapshot) -> Void in
            self.processMapFromFirebase(key: snapshot.key, values: snapshot.value as! [String: Any])
        }
        mapsRef.observe(.childChanged) { (snapshot) -> Void in
            self.processMapFromFirebase(key: snapshot.key, values: snapshot.value as! [String: Any])
        }
        mapsRef.observe(.childRemoved) { (snapshot) -> Void in
            if let existingMapIndex = self.maps.index(of: snapshot.key) {
                self.maps.remove(at: existingMapIndex)
                self.images.remove(at: existingMapIndex)
                self.files.remove(at: existingMapIndex)
                self.tableView.reloadData()
            }
        }
    }
    
    /// Handles the selection of a row in the table
    ///
    /// - Parameters:
    ///   - tableView: the view for selecting a map
    ///   - indexPath: the row selected by the user
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedRow = indexPath.row
        performSegue(withIdentifier: "userSelectSegue", sender: self)
    }
    
    func processMapFromFirebase(key: String, values: [String: Any]) {
        // only include in the list if it is processed
        if let _ = values["map_file"] as? String { // if not in user folder, public map
            processMap(mapName: values["name"] as! String, mapInfo: values)
        } else if Auth.auth().currentUser?.uid == key {
            for subkey in values.keys {
                let subval = values[subkey] as? [String: Any]
                if let _ = subval?["map_file"] as? String {
                    processMap(mapName: subval!["name"] as! String, mapInfo: subval!)
                }
            }
        }
    }
    
    func processMap(mapName: String, mapInfo: [String: Any]) {
        // TODO: pick a sensible default image
        print("processing map \(mapName)")
        let imageRef = storageRef.child((mapInfo["image"] as? String) ?? "olin_library.jpg")
        imageRef.getData(maxSize: 10*1024*1024) { imageData, error in
            if let error = error {
                print(error.localizedDescription)
                // Error occurred
            } else {
                if let data = imageData {
                    self.images.append(UIImage(data: data)!)
                    self.files.append(mapInfo["map_file"] as! String)
                    self.maps.append(mapName)
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    
    /// Sends the name of the selected map to the main view controller while the app is transitioning between views
    ///
    /// - Parameters:
    ///   - segue: the segue that occurs between the ChooseMapViewController and the ViewController when a table row is selected
    ///   - sender: an indication that somewhere on the table has been pressed
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "userSelectSegue" {
            if let viewController = segue.destination as? ViewController {
                viewController.mapFileName = files[selectedRow]
            }
        }
    }
    
    //enable deleting the cell by swiping
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if let cell = tableView.cellForRow(at: indexPath) as? ChooseMapTableViewCell {
                Database.database(url: "https://invisible-map-sandbox.firebaseio.com/").reference(withPath: "maps").child(cell.mapName.text!).removeValue()
            }
        }
    }
}


// MARK: - Handles the population of the table view and the selection of a table view element
extension ChooseMapViewController {
    
    
    /// Gets the number of rows the table view should have
    ///
    /// - Parameters:
    ///   - tableView: the view for selecting a map
    ///   - section: the section of the table view of which to find the size
    /// - Returns: the number of rows in the table view
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return maps.count
    }
    
    
    /// Adds data to the table
    ///
    /// - Parameters:
    ///   - tableView: the view for selecting a map
    ///   - indexPath: the row to populate with data
    /// - Returns: the cell in the table, populated with data
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ChooseMapTableViewCell
        cell.mapName.text = maps[indexPath.row]
        cell.mapPhoto.image = images[indexPath.row]
        return cell
    }
}
