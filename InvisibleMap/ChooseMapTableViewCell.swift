//
//  ChooseMapTableViewCell.swift
//  InvisibleMap
//
//  Created by Occam Lab on 8/8/18.
//  Copyright © 2018 Occam Lab. All rights reserved.
//

import UIKit

class ChooseMapTableViewCell: UITableViewCell {

    

    @IBOutlet var mapPhoto: UIImageView!
    @IBOutlet var mapName: UILabel!
    
  
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
