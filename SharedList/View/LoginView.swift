//
//  LoginView.swift
//  SharedList
//
//  Created by 박지호 on 11/12/25.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authVM
    
    private let gradient = LinearGradient(
        colors: [Color.orange.opacity(0.3), Color.pink.opacity(0.4), Color.black.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            // 배경 그라데이션
            gradient
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // 앱 로고 및 타이틀
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 80))
                        .foregroundStyle(.white)
                    
                    Text("app_name")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("login_app_description")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Sign in with Apple 버튼
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            authVM.signInWithApple(authorization: authorization)
                        case .failure(let error):
                            authVM.handleError(error)
                        }
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .cornerRadius(8)
                .padding(.horizontal, 40)
                
                // 에러 메시지
                if let errorMessage = authVM.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                    .frame(height: 60)
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
}


