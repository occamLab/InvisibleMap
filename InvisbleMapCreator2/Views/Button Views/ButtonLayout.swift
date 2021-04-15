//
//  ButtonLayout.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/23/21.
//

import SwiftUI

struct RectangleButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: 80, height: 40)
            .padding(5)
            .font(.system(size: 20))
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .foregroundColor(Color(UIColor.systemBackground))
                    .opacity(0.7))
    }
}

struct CircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: CGFloat(40), height: CGFloat(40))
            .padding(10)
            .foregroundColor(.white)
            .font(.system(size: CGFloat(30)))
            .background(
                Circle()
                    .opacity(0.7))
    }
}

struct ButtonLayout: View {
    @State var recording: Bool = false // Track whether map is currently being recorded

    var body: some View {
        VStack {
            HStack {
                ExitButton()
                Spacer()
                SaveButton()
            }
            .padding(20)
            Spacer()
            HStack {
                ManageLocationsButton(recording: $recording)
                Spacer()
                RecordMapButton(recording: $recording)
                Spacer()
                AddLocationButton(recording: $recording)
        }
    }
    }
}

struct ButtonLayout_Previews: PreviewProvider {
    static var previews: some View {
        ButtonLayout().preferredColorScheme(.light)
    }
}
