//
//  DirectionFeeback.swift
//  InvisibleMap2
//
//  Created by occamlab on 7/13/22.
//  Copyright © 2022 Occam Lab. All rights reserved.
//

import Foundation


struct DirectionInfo {
    let clockDirections = [1: "", 2: "", 3: "", 4: "", 5: "", 6: "", 7: "", 8: "", 9: "", 10: "", 11: "", 12: ""]
    let binaryDirection = [
        "straight": NSLocalizedString("straightDirection", comment: "Direction to user to continue moving in forward direction"),
        "slightRight": NSLocalizedString("slightRightDirection", comment: "Direction to user to take a slight right turn"),
        "right": NSLocalizedString("rightDirection", comment: "Direction to the user to make an approximately 90 degree right turn."),
        "uturn": NSLocalizedString("uTurnDirection", comment: "Direction to the user to turn around"),
        "left": NSLocalizedString("leftDirection", comment: "Direction to the user to make an approximately 90 degree left turn."),
        "slightLeft": NSLocalizedString("slightLeftDirection", comment: "Direction to user to take a slight left turn"),
        "none": "ERROR"
       ]
}
