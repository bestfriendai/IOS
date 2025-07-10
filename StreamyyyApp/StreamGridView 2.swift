//
//  StreamGridView.swift
//  StreamyyyApp
//
//  Simple grid view for displaying streams
//

import SwiftUI

struct StreamGridView: View {
    @Binding var streams: [StreamModel]
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(streams) { stream in
                    StreamCard(stream: stream)
                }
            }
            .padding()
        }
    }
}

#Preview {
    StreamGridView(streams: .constant([]))
}