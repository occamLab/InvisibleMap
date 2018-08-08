//
//  ChooseMapViewController.swift
//  InvisibleMap
//
//  Created by Occam Lab on 8/8/18.
//  Copyright © 2018 Occam Lab. All rights reserved.
//

import Foundation


class ChooseMapViewController: UIViewController {
    
    let maps = ["AC", "Library", "Campus Center"]
    let images: [UIImage] = [#imageLiteral(resourceName: "academicCenter"), #imageLiteral(resourceName: "academicCenter"), #imageLiteral(resourceName: "academicCenter")]
    
    @IBOutlet var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //tableView.estimatedRowHeight = 120
        //tableView.rowHeight = UITableViewAutomaticDimension
        //tableView.reloadData()
        
        // Do any additional setup after loading the view, typically from a nib.
        
        
    }
}

extension ChooseMapViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return maps.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ChooseMapTableViewCell
        cell.mapName.text = maps[indexPath.row]
        //cell.heightAnchor = 120
        cell.mapPhoto.image = images[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // pass
    }
    
    
}
