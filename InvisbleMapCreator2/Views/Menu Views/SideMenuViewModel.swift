//
//  SideMenuViewModel.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/5/21.
//

import Foundation

enum SideMenuViewModel: Int, CaseIterable {
    case printTags
    case manageMaps
    case settings
    case videoWalkthrough
    case giveFeedback
    
    var title: String {
        switch self {
        case .printTags: return "Print tags"
        case .manageMaps: return "Manage maps"
        case .settings: return "Settings"
        case .videoWalkthrough: return "Video walkthrough"
        case .giveFeedback: return "Give feedback"
        }
    }
    
    var imageName: String? {
        switch self {
        case .printTags: return "printer.fill.and.paper.fill"
        case .manageMaps: return "map.fill"
        case .settings: return "gearshape.fill"
        case .videoWalkthrough: return nil
        case .giveFeedback: return nil
        }
    }
}
