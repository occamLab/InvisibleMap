//
//  DirectionFeeback.swift
//  InvisibleMap2
//
//  Created by Joyce Chung on 7/13/22.
//  Adapted from Clew Maps' Navigation.swift
//  Copyright © 2022 Occam Lab. All rights reserved.
//

import Foundation

/// Current state of the user along the path in the map relative to the endpoint
public enum PositionState {
    /// user is far from endpoint
    case notAtEndpoint
    /// user is at endpoint
    case atEndpoint
    /// user is close to the endpoint
    case closeToEndpoint
}

/// Struct to store information about user's current position relative to path on map
public struct DirectionInfo {
    /// key of the clock direction that's associated with the description of the angle to next keypoint
    public var clockDirectionKey: Int
    /// key of the binary direction that's associated with the description of the angle to next keypoint
    public var binaryDirectionKey: String
    /// distance in meters from the tag or waypoint destination
    public var distanceToEndpoint: Float
    /// angle in radians of the user's current path from the right path in the map
    public var angleDiffFromPath: Float
    public var endPointState = PositionState.notAtEndpoint
    
    /// Initialize a DirectionInfo Object
    public init(clockDirectionKey: Int, binaryDirectionKey: String, distanceToEndpoint: Float, angleDiffFromPath: Float) {
        self.clockDirectionKey = clockDirectionKey
        self.binaryDirectionKey = binaryDirectionKey
        self.distanceToEndpoint = distanceToEndpoint
        self.angleDiffFromPath = angleDiffFromPath
    }
}
    
    /// Dictionary of clock directions
    ///
    /// * Keys (`Int` from 1 to 12 inclusive): clock position
    /// * Values (`String`): corresponding spoken direction (e.g. "Slight right towards 2 o'clock")
    public let ClockDirections = [12: NSLocalizedString("straightDirection", comment: "Direction to user to continue moving in forward direction"),
                           1: NSLocalizedString("1o'clockDirection", comment: "direction to the user to turn towards the 1 o'clock direction"),
                           2: NSLocalizedString("2o'clockDirection", comment: "direction to the user to turn towards the 2 o'clock direction"),
                           3: NSLocalizedString("rightDirection", comment: "Direction to the user to make an approximately 90 degree right turn."),
                           4: NSLocalizedString("4o'clockDirection", comment: "direction to the user to turn towards the 4 o'clock direction"),
                           5: NSLocalizedString("5o'clockDirection", comment: "direction to the user to turn towards the 5 o'clock direction"),
                           6: NSLocalizedString("6o'clockDirection", comment: "direction to the user to turn towards the 6 o'clock direction"),
                           7: NSLocalizedString("7o'clockDirection", comment: "direction to the user to turn towards the 7 o'clock direction"),
                           8: NSLocalizedString("8o'clockDirection", comment: "direction to the user to turn towards the 8 o'clock direction"),
                           9: NSLocalizedString("leftDirection", comment: "Direction to the user to make an approximately 90 degree left turn."),
                           10: NSLocalizedString("10o'clockDirection", comment: "direction to the user to turn towards the 10 o'clock direction"),
                           11: NSLocalizedString("11o'clockDirection", comment: "direction to the user to turn towards the 11 o'clock direction")]
    
    /// Dictionary of binary (L/R) directions.
    ///
    /// * Keys (`String`: coresponding to direction
    /// * Values (`String`): corresponding spoken direction (e.g. "Slight right")
    public let BinaryDirections = [
        "straight": NSLocalizedString("straightDirection", comment: "Direction to user to continue moving in forward direction"),
        "slightRight": NSLocalizedString("slightRightDirection", comment: "Direction to user to take a slight right turn"),
        "right": NSLocalizedString("rightDirection", comment: "Direction to the user to make an approximately 90 degree right turn."),
        "uturn": NSLocalizedString("uTurnDirection", comment: "Direction to the user to turn around"),
        "left": NSLocalizedString("leftDirection", comment: "Direction to the user to make an approximately 90 degree left turn."),
        "slightLeft": NSLocalizedString("slightLeftDirection", comment: "Direction to user to take a slight left turn"),
        "none": "ERROR"
       ]

/// Navigation class that provides direction information based on current camera position and the endpoint position in the mapFrame
/*class Navigation {
    public var endpoint
} */

