//
//  FindTagOverlay.swift
//  InvisbleMapCreator2
//
//  Created by Marion Madanguit on 5/7/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct FindTagOverlay: View {
    var body: some View {
        VStack {
            Text("Point your camera at a tag")
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

struct FindTagOverlay_Previews: PreviewProvider {
    static var previews: some View {
        FindTagOverlay()
    }
}
