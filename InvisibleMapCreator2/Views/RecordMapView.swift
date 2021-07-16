//
//  RecordMapView.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/14/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI
import ARKit

// Stores the ARView
struct NavigationIndicator: UIViewControllerRepresentable {
   typealias UIViewControllerType = ARView
   func makeUIViewController(context: Context) -> ARView {
      return ARView()
   }
   func updateUIViewController(_ uiViewController:
   NavigationIndicator.UIViewControllerType, context:
   UIViewControllerRepresentableContext<NavigationIndicator>) { }
}

// Describes all the instructions that will exist on-screen for the user
enum InstructionType {
    case findTag
    case saveLocation
    case findTagReminder
    case none
    
    var text: String? {
        get {
            switch self {
            case .findTag: return "Point your camera at a tag"
            case .saveLocation: return "First tag found! \nYou can now save a location"
            case .findTagReminder: return "You must find a tag first before you can save a location"
            case .none: return nil
            }
        }
        set {
            switch self {
            case .findTag: self = .findTag
            case .saveLocation: self = .saveLocation
            case .findTagReminder: self = .findTagReminder
            case .none: self = .none
            }
        }
    }
}

struct NodeData: Identifiable {
    let id = UUID()
    var node: SCNNode
    var picture: UIImage
    var textNode: SCNNode
    var poseId: Int
}

// Provides persistent storage for on-screen instructions and state variables outside of the view struct
class RecordGlobalState: ObservableObject, RecordViewController {
    @Published var tagFound: Bool
    @Published var instructionWrapper: InstructionType
    @Published var nodeList: [NodeData]

    init() {
        tagFound = false
        instructionWrapper = .findTag
        nodeList = []
        AppController.shared.recordViewer = self
    }
    
    // Record view controller commands
    func enableAddLocation() {
        DispatchQueue.main.async {
            if self.tagFound {
                self.instructionWrapper = .none
            } else {
                self.tagFound = true
                self.instructionWrapper = .saveLocation
            }
        }
    }
    
    func updateLocationList(node: SCNNode, picture: UIImage, textNode: SCNNode, poseId: Int) {
        self.nodeList.append(NodeData(node: node, picture: picture, textNode: textNode, poseId: poseId))
    }
}

struct RecordMapView: View {
    @StateObject var recordGlobalState = RecordGlobalState() 
    
    var body : some View {
        ZStack {
            NavigationIndicator().edgesIgnoringSafeArea(.all)
                // Hides the default navigation bar so that we can replace it with custom exit and save buttons
                // .navigationBarHidden(true)
                .navigationBarBackButtonHidden(true)
                // Toolbar buttons
                .toolbar(content: {
                    ToolbarItem(placement: .navigationBarLeading) {
                        ExitButton()
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        SaveButton()
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        HStack {
                            AddLocationButton(recordGlobalState: recordGlobalState)
                            ManageLocationsButton(recordGlobalState: recordGlobalState)
                        }
                    }
                })
            VStack {
                // Shows instructions if there are any
                if recordGlobalState.instructionWrapper.text != nil {
                    InstructionOverlay(instruction: $recordGlobalState.instructionWrapper.text)
                        .animation(.easeInOut)
                }
                RecordTagButton()
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .padding()
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            AppController.shared.startRecordingRequested()
        }
    }
}

extension UINavigationController {
    override open func viewDidLoad() {
        super.viewDidLoad()
      
        // Creates a translucent toolbar
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithTransparentBackground()
        toolbarAppearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)
        UIToolbar.appearance().standardAppearance = toolbarAppearance
    }
}

struct RecordMapView_Previews: PreviewProvider {
    static var previews: some View {
        RecordMapView()
    }
}
