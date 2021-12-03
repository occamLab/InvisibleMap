//
//  ViewStructs.swift
//  InvisibleMap
//
//  Created by occamlab on 11/30/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

// Defines a button style for all the rectangle buttons
struct RectangleButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: 80, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .foregroundColor(Color(UIColor.systemBackground))
                    .opacity(0.7))
    }
}
