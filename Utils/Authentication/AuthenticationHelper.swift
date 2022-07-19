//
//  AuthenticationHelper.swift
//  Clew
//
//  Created by Paul Ruvolo on 4/16/21.
//  Copyright © 2021 OccamLab. All rights reserved.
//

import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Firebase

class AuthenticationHelper: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var window: UIWindow?
    
    init(window: UIWindow?) {
        self.window = window
    }
    
    // Adapted from https://auth0.com/docs/api-auth/tutorials/nonce#generate-a-cryptographically-random-nonce
    private func randomNonceString(length: Int = 32) -> String {
      precondition(length > 0)
      let charset: Array<Character> =
          Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
      var result = ""
      var remainingLength = length

      while remainingLength > 0 {
        let randoms: [UInt8] = (0 ..< 16).map { _ in
          var random: UInt8 = 0
          let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
          if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
          }
          return random
        }

        randoms.forEach { random in
          if remainingLength == 0 {
            return
          }

          if random < charset.count {
            result.append(charset[Int(random)])
            remainingLength -= 1
          }
        }
      }

      return result
    }
    // Unhashed nonce.
    fileprivate var currentNonce: String?

    @available(iOS 13, *)
    func startSignInWithAppleFlow() {
      let nonce = randomNonceString()
    print("created random ID name")
      currentNonce = nonce
      let appleIDProvider = ASAuthorizationAppleIDProvider()
        print("created appleID provider whatever that means")
      let request = appleIDProvider.createRequest()
        print("created apple ID request")
      request.requestedScopes = [.fullName, .email]
        print("name and email: \(request.requestedScopes)")
      request.nonce = sha256(nonce)

      let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        print("authorization controller: \(authorizationController)")
      authorizationController.delegate = self
      authorizationController.presentationContextProvider = self
      authorizationController.performRequests()
    }

    @available(iOS 13, *)
    private func sha256(_ input: String) -> String {
      let inputData = Data(input.utf8)
      let hashedData = SHA256.hash(data: inputData)
      let hashString = hashedData.compactMap {
        return String(format: "%02x", $0)
      }.joined()

      return hashString
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("good function happening: Sign in with apple id pressed")
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
          guard let nonce = currentNonce else {
            fatalError("Invalid state: A login callback was received, but no login request was sent.")
          }
          guard let appleIDToken = appleIDCredential.identityToken else {
            print("Unable to fetch identity token")
            return
          }
          guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
            return
          }
          // Initialize a Firebase credential.
          let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                    idToken: idTokenString,
                                                    rawNonce: nonce)
          // Sign in with Firebase.
          Auth.auth().signIn(with: credential) { (authResult, error) in
            if (error != nil) {
                // Error. If error.code == .MissingOrInvalidNonce, make sure
                // you're sending the SHA256-hashed nonce as a hex string with
                // your request to Apple.
                print("Received error during sign in: \(error!.localizedDescription)")
                print("Transitioning to main app with error")
                self.transitionToMainApp()
                return
            }
            // User is signed in to Firebase with Apple.
            // ...
            print("Transitioning to main app")
            self.transitionToMainApp()

          }
        }
      }

    func presentationAnchor(for controller: ASAuthorizationController)-> ASPresentationAnchor {
        return window!
    }
    
    // when user hits 'Cancel' button in Sign-in pop up or there's an error signing in
      func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle error.
        print("Sign in with Apple errored: \(error)")
          
          // current status: disable signing in anonymously
        /*  Auth.auth().signInAnonymously() { (authResult, error) in
            guard let _ = authResult else {
                print("Anonymous login error", error!.localizedDescription)
                return
            }
            print("Successful anonymous login \(String(describing: Auth.auth().currentUser?.uid))")
            print("user acc status: \(Auth.auth().currentUser?.isAnonymous)")
         //   try! Auth.auth().signOut()
           // self.transitionToMainApp()
          } */
      }
        
    
    func transitionToMainApp() {
    }

}

