//
//  SaveButton.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/13/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI
import AudioToolbox

struct SaveButton: View {
    @Environment(\.presentationMode) var mode: Binding<PresentationMode> // Tracks whether the RecordMap screen is being presented
    @State private var showEmptyMapNameWarning = false

    var body: some View {
        Button(action: {
            alert()
        }){
            Text("Save")
                .accessibility(label: Text("Save Map"))
        }
        .buttonStyle(RectangleButtonStyle())
        .alert("Error!\nYou must enter a valid map name.", isPresented: $showEmptyMapNameWarning) {
                    Button("OK", role: .cancel) {
                        alert()
                    }
        }
    }
}

extension SaveButton { // Creates an alert with a textfield (functionality currently unavailable in SwiftUI)
    private func alert() {
        let alert = UIAlertController(title: "Save Map", message: "Would you like to save this map? \nNote: You cannot edit this map \nafter saving as of now.", preferredStyle: .alert)
        alert.addTextField() { textField in
            textField.placeholder = "Name map here"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in })
        alert.addAction(UIAlertAction(title: "Save", style: .default) { (action: UIAlertAction) in
            if let text = alert.textFields?.first?.text {
                //ensure that valid map name is entered
                if !text.isEmptyOrWhitespace() {
                    let textNoSlash = text.replacingOccurrences(of: "/", with: "-")
                    InvisibleMapCreatorController.shared.process(event: .SaveMapRequested(mapName:  textNoSlash)) // Tells the state machine to save the map
                    self.mode.wrappedValue.dismiss()
                }
                else {
                    //vibrate phone and tell user to enter a valid name
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    self.showEmptyMapNameWarning = true
                    
                }
            }
        })
        showAlert(alert: alert)
    }

    func showAlert(alert: UIAlertController) {
        if let controller = topMostViewController() {
            controller.present(alert, animated: true)
        }
    }

    private func keyWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
        .filter {$0.activationState == .foregroundActive}
        .compactMap {$0 as? UIWindowScene}
        .first?.windows.filter {$0.isKeyWindow}.first
    }

    private func topMostViewController() -> UIViewController? {
        guard let rootController = keyWindow()?.rootViewController else {
            return nil
        }
        return topMostViewController(for: rootController)
    }

    private func topMostViewController(for controller: UIViewController) -> UIViewController {
        if let presentedController = controller.presentedViewController {
            return topMostViewController(for: presentedController)
        } else if let navigationController = controller as? UINavigationController {
            guard let topController = navigationController.topViewController else {
                return navigationController
            }
            return topMostViewController(for: topController)
        } else if let tabController = controller as? UITabBarController {
            guard let topController = tabController.selectedViewController else {
                return tabController
            }
            return topMostViewController(for: topController)
        }
        return controller
    }
}
extension String {
    func isEmptyOrWhitespace() -> Bool {
        
        // Check empty string
        if self.isEmpty {
            return true
        }
        // Trim and check empty string
        return (self.trimmingCharacters(in: .whitespaces) == "")
    }
}


struct SaveButton_Previews: PreviewProvider {
    static var previews: some View {
        SaveButton()
    }
}
