//
//  AddLocationButton.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 4/16/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct AddLocationButton: View {
    @ObservedObject var recordGlobalState: RecordGlobalState
    
    var body: some View {
        Button(action: {
            if recordGlobalState.tagFound {
                recordGlobalState.instructionWrapper = .none // Removes on-screen instructions after the user has successfully added their first location
                alert()
            } else {
                recordGlobalState.instructionWrapper = .findTagReminder // Sends a find tag reminder to the user if they try to add a location before they've found their first tag
            }
        }){
            HStack {
                Image(systemName: "plus")
                Text("Add Location")
            }
        }
        // Button styling for the AddLocation button
        .frame(width: 200, height: 40)
        .foregroundColor(.white)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .foregroundColor(.green))
        .opacity(recordGlobalState.tagFound ? 1 : 0.5)
        //.disabled(tagFound ? false: true)
    }
}

extension AddLocationButton { // Creates an alert with a textfield (functionality currently unavailable in SwiftUI)
    private func alert() {
        let alert = UIAlertController(title: "Name Location", message: nil, preferredStyle: .alert)
        alert.addTextField() { textField in
            textField.placeholder = ""
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in })
        alert.addAction(UIAlertAction(title: "Save", style: .default) { (action: UIAlertAction) in
            if let text = alert.textFields?.first?.text {
                AppController.shared.saveLocationRequested(locationName: text) // Tells the state machine to save the location
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

struct AddLocationButton_Previews: PreviewProvider {
    @StateObject static var recordGlobalState = RecordGlobalState()

    static var previews: some View {
        AddLocationButton(recordGlobalState: recordGlobalState)
    }
}
