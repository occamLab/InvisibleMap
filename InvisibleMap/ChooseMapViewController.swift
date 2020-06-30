//
//  ChooseMapViewController.swift
//  InvisibleMap
//
//  Created by djconnolly27 on 8/8/18.
//  Copyright © 2018 Occam Lab. All rights reserved.
//

import Foundation
import Firebase


/// A View Controller for handling map selection
class ChooseMapViewController: UIViewController {
    
    
    //MARK: Properties
    var maps: [String] = []
    var images: [UIImage] = []
    var files: [String] = []
    var selectedRow = 0
    
    @IBOutlet var tableView: UITableView!
    
    /// Populates the table view with data from firebase as the app is loaded
    override func viewDidLoad() {
        super.viewDidLoad()
        let storageRef = Storage.storage().reference()
        let mapsRef = Database.database().reference(withPath: "maps")
        mapsRef.observe(.childAdded) { (snapshot) -> Void in
            let values = snapshot.value as! [String: Any]
            // only include in the list if it is processed
            if let processedMapFile = values["map_file"] as? String {
                let imageRef = storageRef.child(values["image"] as! String)
                imageRef.getData(maxSize: 10*1024*1024) { imageData, error in
                    if let error = error {
                        print(error.localizedDescription)
                        // Error occurred
                    } else {
                        if let data = imageData {
                            self.images.append(UIImage(data: data)!)
                            self.files.append(processedMapFile)
                            self.maps.append(snapshot.key)
                            self.tableView.reloadData()
                        }
                    }
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
}


// MARK: - Handles the population of the table view and the selection of a table view element
extension ChooseMapViewController: UITableViewDelegate, UITableViewDataSource {
    
    
    /// Gets the number of rows the table view should have
    ///
    /// - Parameters:
    ///   - tableView: the view for selecting a map
    ///   - section: the section of the table view of which to find the size
    /// - Returns: the number of rows in the table view
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return maps.count
    }
    
    
    /// Adds data to the table
    ///
    /// - Parameters:
    ///   - tableView: the view for selecting a map
    ///   - indexPath: the row to populate with data
    /// - Returns: the cell in the table, populated with data
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ChooseMapTableViewCell
        cell.mapName.text = maps[indexPath.row]
        cell.mapPhoto.image = images[indexPath.row]
        return cell
    }
    
    
    /// Handles the selection of a row in the table
    ///
    /// - Parameters:
    ///   - tableView: the view for selecting a map
    ///   - indexPath: the row selected by the user
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedRow = indexPath.row
        self.performSegue(withIdentifier: "userSelectSegue", sender: self)
    }
    
    
}
