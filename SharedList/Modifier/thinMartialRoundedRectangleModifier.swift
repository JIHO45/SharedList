//
//  SwiftUIView.swift
//  SharedList
//
//  Created by 박지호 on 11/17/25.
//

import SwiftUI

struct thinMartialRoundedRectangleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 8)
    }
}
