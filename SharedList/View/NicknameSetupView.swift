//
//  NicknameSetupView.swift
//  SharedList
//
//  Created by 박지호 on 11/12/25.
//

import SwiftUI

struct NicknameSetupView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var nickname: String = ""
    
    private let gradient = LinearGradient(
        colors: [Color.orange.opacity(0.3), Color.pink.opacity(0.4), Color.black.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            gradient
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white)
                    
                    Text("set_nickname")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("nickname_display_info")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                VStack(spacing: 16) {
                    TextField(String(localized: "enter_nickname"), text: $nickname)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .onSubmit {
                            saveNickname()
                        }
                    
                    Button {
                        saveNickname()
                    } label: {
                        Text("confirm")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 40)
                
                if let errorMessage = authVM.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
            }
        }
    }
    
    private func saveNickname() {
        authVM.setNickname(nickname)
    }
}

#Preview {
    NicknameSetupView()
        .environment(AuthViewModel())
}


