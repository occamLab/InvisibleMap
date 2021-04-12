//
//  SideMenuOptionView.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/5/21.
//

import SwiftUI

struct SideMenuOptionView: View {
    let viewModel: SideMenuViewModel
    
    var body: some View {
        HStack(spacing: 24) {
            if viewModel.imageName != nil {
                Image(systemName: viewModel.imageName!)
                    .font(.title)
                    .frame(width: 24, height: 24)
            }
            
            Text(viewModel.title)
                .font(.title)
            
            Spacer()
        }
        .padding()
    }
}

struct SideMenuContentView_Previews: PreviewProvider {
    static var previews: some View {
        SideMenuOptionView(viewModel: .settings)
    }
}
