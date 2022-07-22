//
//  AppleSignInController.swift
//  Clew
//
//  Created by Jasper Katzban on 3/31/21.
//  Copyright © 2021 OccamLab. All rights reserved.
//

import UIKit
import SwiftUI
import Firebase
import FirebaseAuth

/// A View Controller for signing user in with apple ID for logging purposes
@available(iOS 13.0, *)
class AppleSignInController: UIViewController {
    
    var authHelper: AuthenticationHelper?
    
    var signInTitle: UILabel!
    
    var signInDescription: UILabel!

    var signInButton: UIButton!
    
    /// called when the view has loaded.  We setup various app elements in here.
    override func viewDidLoad() {
        super.viewDidLoad()
        signInWithApple()
    }
        
    @objc private func signInWithApple() {
        authHelper = AuthenticationHelper(window: nil)
        print("auth helper created")
        authHelper?.startSignInWithAppleFlow()
        print("auth helper start sign in with apple flow")
    }
}
