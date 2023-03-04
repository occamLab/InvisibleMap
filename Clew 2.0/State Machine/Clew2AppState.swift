//
//  AppState.swift
//  Clew 2.0
//
//  Created by Joyce Chung & Gabby Blake on 2/11/23.
//  Copyright © 2023 Occam Lab. All rights reserved.
//

import Foundation
import ARKit //change

indirect enum Clew2AppState: StateType {
    // Higher level app states
    case HomeScreen
    case FamilyScreen
    case LocationScreen
    case POIScreen
    case CreateARView(CreateMapState)
    case NavigateARView(NavigateMapState)
    
    // Initial state upon opening the app
    static let initialState = Clew2AppState.HomeScreen
    
    // All the effectual inputs from the app which the state can react to
    enum Event {
        // HomeScreen events
        case CreateMapRequested
        case LocateUserRequested
        case LocationSelected
        case DomainSelected(mapName: String) // top of name hierarchy (i.e. Food & Drinks)
        case FamilySelected(mapName: String) // next in name hierarchy (i.e. Restaurants - one option in Food & Drinks)
        case LocationSelected(mapName: String) // (i.e. Cheescake Factory - a restaurant)
        case ReviewsSelected(mapName: String) // users want to see the reviews for the POIs in this map
        case POISelected(mapName: String) // last in name hierarchy (i.e. Restroom in Cheescake Factory)
        
        // CreateMap events
        case DropGeospatialAnchorRequested
        case DropCloudAnchorRequested
        case DropDoorAnchorRequested
        case DropStairAnchorRequested
        case ViewPOIsRequested
        case NamePOIRequested
        case SaveMapRequested(mapName: String)
        case CancelMapRequested
        
        case NewARFrame(cameraFrame: ARFrame) // to update AR screen during map creation
        case NewTagFound(tag: AprilTags, cameraTransform: simd_float4x4, snapTagsToVertical: Bool) // if we are still using April tags
        case PlanesUpdated(planes: [ARPlaneAnchor])
        
        // NavigateMap events
        case PreviewDirectionSelected(mapName: String)
        case LeaveMapRequested(mapName: String) // takes users to POIScreen state
        case ChangeRouteRequested(mapName: String) // we may need to save the mapName so that we can redirect users to a new POI destination
        case EndpointReached
        case RateMapRequested(mapName: String)
        case HomeScreenRequested
    }
    
    // All the effectful outputs which the state desires to have performed on the app
    enum Command {
        // HomeScreen commands
        case LoadFamilyScreen(mapName: String)
        case LoadLocations(mapName: String)
        case LoadPOIs(mapName: String)
        
        // CreateMap commands
        case LocateAndCategorizeMap // user uses GPS to automatically categorize the map - map still needs to be named
        case NameMap(mapName: String)
        case LoadAndCategorizeMap(mapName: String) // user searches for a location that doesn't have a map yet and creates a map for that location - map already named
        case DropGeospatialAnchor // anchors outside the establishment
        // * cloud anchors for inside the establishment
        case DropCloudAnchor
        case DropDoorAnchor
        case DropStairAnchor
        case DropCloudAnchor // cloud anchors are both breadcrumbs and can be named as POIs - need to figure out the time interval at which it should be dropped or if we should make users drop it frequently and name those that they want to
        case NamePOI
        case ViewPOIs
        case SaveMap(mapName: String)
        case CancelMap
        
        // NavigateMap commands
        case LoadReviews
        case StartNavigation
        case LoadPreviewDirections
        case LeaveMap
        case ModifyRoute // or StartNavigation? to a new endpoint
        case LoadRatePopUp
    }
    
    // In response to an event, a state may transition to a new state, and it may emit a command
    mutating func handle(event: Event) -> [Command] {
        print("Last State: \(self), \(event)")
        switch (self, event) {
        case (.HomeScreen, .CreateMapRequested):
            self = .NameMapScreen
            return [.NameMap] // should we send to Firebase after user presses 'Finished'?
            
        // user finds a map's POIs without shortcut/searchbar - i.e. selects a domain -> ... -> POI
        case (.HomeScreen, .DomainSelected(let mapName)):
            self = .FamilyScreen
            return [.LoadFamilyScreen(mapName: mapName)]
        case (.DomainSelected(let mapName), .FamilySelected(let mapName)):
            self = .LocationScreen
            return [.LoadLocations(mapName: mapName)]
        case (.FamilyScreen, .LocationSelected(let mapName)):
            self = .POIScreen
            return [.LoadPOIs(mapName: mapName)]
        // user finds a map's POIs through the search bar - takes shortcut
        case (.HomeScreen, .LocationSelected(let mapName)):
            self = .POIScreen
            return [.LoadPOIs(mapName: mapName)]
        
        // handling lower level events for CreateMapState
        case (.CreateARView(let state), _) where CreateMapState.Event(event) != nil:
            var newState = state
            let commands = newState.handle(event: CreateMapState.Event(event)!)
            self = .CreateARView(newState)
            return commands
            
        // handling lower level events for NavigateMapState
        case (.NavigateARView(let state), _) where NavigateMapState.Event(event) != nil:
            var newState = state
            let commands = newState.handle(event: NavigateMapState.Event(event)!)
            self = .NavigateARView(newState)
            return commands
        
        case (.POIScreen, .CreateMapRequested):
            self = .NameMapScreen
            return [.NameMap]
        case (.NameMapScreen, .LocateUserRequested):
            self = .CreateARView
            return [.LocateAndCategorizeMap]
            
            
        case (.CreateARView, .DropGeospatialAnchorRequested):
            self = .CreateARView
            return [.DropGeospatialAnchor]
        case (.CreateARView, .ViewPOIsRequested):
            self = .ViewPOIState // not be a state?
            return [.ViewPOIs]
        case (.CreateARView, .DropDoorAnchorRequested):
            self = .DropDoorAnchorState
            return [.DropDoorAnchor]
        case (.CreateARView, .DropStairAnchorRequested):
            self = .DropStairAnchorState
            return [.DropDoorAnchor]
        case (.CreateARView, .DropCloudAnchorRequested):
            self = .CreateARView
            return [.DropCloudAnchor]
        case (.CreateARView, .NamePOIRequested)
            self = .CreateARView
            return [.NamePOI]
        
            
        
            


            default: break
        }
        return []
    }
}

enum CreateMapState: StateType {
    // Lower level app states nested within CreateMapState
    case CreateARView
    case NameMapScreen  // for the purpose of naming hierarchy - to keep maps organized into folders
   //case CreateGeospatialAnchor // dropping geospatial anchors
   // case CreateCloudAnchor // dropping cloud anchors
    case ARView
    case DropDoorAnchorState
    case DropStairAnchorState
    case ViewPOIState // viewing points of interests that the user has dropped from the ARView, CreateMap
    
    // Initial state upon transitioning into the CreateMapState
    static let initialState = CreateMapState.CreateARView
    
    // All the effectual inputs from the app which CreateMapState can react to
    enum Event {
        case
    }
    
    // Refers to commands defined in Clew2AppState - adds onto created commands for CreateMapState
    typealias Command = Clew2AppState.Command
    
    // In response to an event, CreateMapState may emit a command
    mutating func handle(event:Evnet) -> [Command] {
        switch (self, event) {
            
        default: break
        }
        return []
    }
}

// Translate between events in Clew2AppState and events in CreateMapState
extension CreateMapState.Event {
    init?(_ event: Clew2AppState.Event) {
        switch event {
            
        default: return nil
        }
    }
}

enum NavigateMapState: StateType {
    // Lower level app states nested within NavigateMapState
    case NavigateARView
    case ReviewsScreen
    case NewARView
    case PreviewDirectionScreen
    
    // Initial state upon transitioning into the NavigateMapState
    static let initialState = NavigateMapState.NavigateARView
    
    // All the effectual inputs from the app which NavigateMapState can react to
    enum Event {
        case
    }
    
    // Refers to commands defined in Clew2AppState - adds onto created commands for NavigateMapState
    typealias Command = Clew2AppState.Command
    
    // In response to an event, CreateMapState may emit a command
    mutating func handle(event:Evnet) -> [Command] {
        switch (self, event) {
            
        default: break
        }
        return []
    }
}

// Translate between events in Clew2AppState and events in NavigateMapState
extension NavigateMapState.Event {
    init?(_ event: Clew2AppState.Event) {
        switch event {
            
        default: return nil
        }
    }
}
