//
//  ChooseModeController.swift
//  InvisibleMapCreator copy
//
//  Created by SeungU on 7/30/20.
//  Copyright © 2020 Occam Lab. All rights reserved.
//

import UIKit

class ChooseModeController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func InvisibleMapButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: "InvisibleMap", sender: self)
    }
    
    @IBAction func MapCreatorButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: "MapCreator", sender: self)
    }
}
