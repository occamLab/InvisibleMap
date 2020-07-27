//
//  SaveLocationController.swift
//  AprilTagDetector
//
//  Created by SeungU on 6/22/20.
//  Copyright © 2020 MyOrganization. All rights reserved.
//

import UIKit

// protocol needed to send the data back as dismissing this view
protocol writeInfoBackDelegate: class {
    func writeValueBack(value: LocationData)
}

class EditInfoController: UIViewController {

    @IBOutlet var locationImage: UIImageView!
    // delegate to send data back
    weak var delegate: writeInfoBackDelegate?
    
    var locationData: LocationData?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationImage.image = locationData!.picture
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

