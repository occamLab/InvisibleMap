//
//  FeedbackView.swift
//  InvisibleMap
//
//  Created by Joyce Chung on 7/3/22.
//  Copyright © 2022 Occam Lab. All rights reserved.
//

import SwiftUI

struct FeedbackView: View {
    @Binding var showFeedbackView: Bool
    
    var body: some View {
        NavigationView {
            Text("Feedback View in progress. \n\nFor Co-designers - Please provide feedback on the google forms we sent out for Invisible Map Creator feedback. Feel free to Slack message or email Joyce (dc103@wellesley.edu) or Gabby (gblake@olin.edu) with any questions or comments that you may have.")
            
            .navigationBarTitle(Text("Invisible Map Creator Feedback"), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                self.showFeedbackView = false
            }) {
                Text("Done").bold()
            })
        }
    }
}
