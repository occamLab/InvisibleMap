//
//  ChooseMapViewController.swift
//  InvisibleMap
//
//  Created by Occam Lab on 8/8/18.
//  Copyright © 2018 Occam Lab. All rights reserved.
//

import Foundation
import Firebase

class ChooseMapViewController: UIViewController {
    
    var maps: [String] = []
    var images: [UIImage] = []
    var files: [String] = []
    var selectedRow = 0
    
    @IBOutlet var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let storageRef = Storage.storage().reference()
        let mapsRef = Database.database().reference(withPath: "maps")
        mapsRef.observe(.childAdded) { (snapshot) -> Void in
            let values = snapshot.value as! [String: Any]
            let imageRef = storageRef.child(values["image"] as! String)
            imageRef.getData(maxSize: 10*1024*1024) { imageData, error in
                if let error = error {
                    print(error.localizedDescription)
                    // Error occurred
                } else {
                    if let data = imageData {
                        self.images.append(UIImage(data: data)!)
                        self.files.append(values["map_file"] as! String)
                        self.maps.append(snapshot.key)
                        self.tableView.reloadData()
                    }
                }
            }
        }

    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "userSelectSegue" {
            if let viewController = segue.destination as? ViewController {
                viewController.mapFileName = files[selectedRow]
            }
        }
    }
}

extension ChooseMapViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return maps.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ChooseMapTableViewCell
        cell.mapName.text = maps[indexPath.row]
        cell.mapPhoto.image = images[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedRow = indexPath.row
        self.performSegue(withIdentifier: "userSelectSegue", sender: self)
    }
    
    
}
