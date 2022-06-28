//
//  InstructionOverlay.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 5/7/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct InstructionOverlay: View {
    @Binding var instruction: String? // On-screen instruction text for the user

    var body: some View {
        VStack {
            Text(instruction!)
                .foregroundColor(Color.white)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .foregroundColor(.black)
                .opacity(0.5))
    }
}

struct InstructionOverlay_Previews: PreviewProvider {
    @State static var instruction: String? = "Point your camera at a tag"

    static var previews: some View {
        InstructionOverlay(instruction: $instruction)
    }
}
