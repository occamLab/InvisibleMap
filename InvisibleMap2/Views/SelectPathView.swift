//
//  SelectPathView.swift
//  InvisibleMap2
//
//  Created by occamlab on 11/30/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct SelectPathView: View {
    let mapFileName: String
    var map: Map?
    
    init(map: String) {
        self.mapFileName = map
        self.onAppear() {
            self.map = FirebaseManager.createMap(from: self.mapFileName)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(Array(self.map!.tagDictionary.keys), id: \.self) { location in
                        NavigationLink(destination: NavigateMapView(map: self.map!)) {
                            Text("\(location)")
                        }
                    }
                }
            }
        }
    }
}

struct SelectPathView_Previews: PreviewProvider {
    static var previews: some View {
        SelectPathView(map: "Test")
    }
}
