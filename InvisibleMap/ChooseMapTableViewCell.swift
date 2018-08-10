//
//  ChooseMapTableViewCell.swift
//  InvisibleMap
//
//  Created by djconnolly27 on 8/8/18.
//  Copyright © 2018 Occam Lab. All rights reserved.
//

import UIKit


/// The format of a cell displaying the map image and name in a table view
class ChooseMapTableViewCell: UITableViewCell {

    //MARK: Properties
    @IBOutlet var mapPhoto: UIImageView!
    @IBOutlet var mapName: UILabel!
    
  
    /// Initialization code
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    
    /// Configure the view for the selected state
    ///
    /// - Parameters:
    ///   - selected: a boolean value indicating whether the cell is selected
    ///   - animated: a boolean value indicating whether to animate the cell if it is selected
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
