//
//  PrintTagsView.swift
//  InvisibleMapCreator
//
//  Created by Marion Madanguit on 3/8/21.
//

import SwiftUI
import PDFKit

// This struct will return pdfView in UIView form to make it SwiftUI compatible
struct PDFViewUI: UIViewRepresentable {
    let pdfView = PDFView()
    var url: URL?
    init(url: URL) {
        self.url = url
    }

    func makeUIView(context: Context) -> UIView {
        if let url = url {
            pdfView.document = PDFDocument(url: url)
        }

        return pdfView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Empty
    }

}

struct PrintTagsView: View {
    var pdfView = PDFViewUI(url: URL(string: "https://www.dotproduct3d.com/uploads/8/5/1/1/85115558/apriltags1-20.pdf")!)
    
    var body: some View {
        pdfView
    }

}

struct PrintTagsView_Previews: PreviewProvider {
    static var previews: some View {
        PrintTagsView()
    }
}
