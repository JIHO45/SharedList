//
//  SettingsView.swift
//  SharedList
//
//  Created by 박지호 on 11/12/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(ListViewModel.self) private var listVM
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var isLogoutAlertPresented = false
    @State private var isDeleteAccountAlertPresented = false
    @State private var isEditNicknameSheetPresented = false
    
    private let supportEmail = "pjh030331@gmail.com"
    
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let version, let build {
            return "\(version) (\(build))"
        }
        return "1.0.0"
    }
    
    private let gradient = LinearGradient(
        colors: [Color.blue.opacity(0.25), Color.purple.opacity(0.35), Color.black.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        NavigationStack {
            ZStack {
                gradient
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 사용자 정보 섹션
                        VStack(spacing: 16) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.white)
                            
                            VStack(spacing: 4) {
                                Button {
                                    isEditNicknameSheetPresented = true
                                } label: {
                                    HStack(spacing: 8) {
                                        if !authVM.nickname.isEmpty {
                                            Text(authVM.nickname)
                                                .font(.title2.bold())
                                                .foregroundStyle(.white)
                                        } else {
                                            Text("user")
                                                .font(.title2.bold())
                                                .foregroundStyle(.white)
                                        }
                                        
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                                
                                if !authVM.userEmail.isEmpty {
                                    Text(authVM.userEmail)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                        
                        // 앱 정보 섹션
                        VStack(alignment: .leading, spacing: 12) {
                            Text("app_info")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Text("version")
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(appVersion)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                Button {
                                    openSupportMail()
                                } label: {
                                    HStack {
                                        Image(systemName: "envelope")
                                        Text("feedback")
                                        Spacer()
                                        Text(supportEmail)
                                            .font(.footnote)
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // 계정 섹션
                        VStack(alignment: .leading, spacing: 12) {
                            Text("account")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 20)
                            
                            Button {
                                isEditNicknameSheetPresented = true
                            } label: {
                                HStack {
                                    Image(systemName: "person.circle")
                                    Text("change_nickname")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal, 20)
                            
                            Button(role: .destructive) {
                                isLogoutAlertPresented = true
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("logout")
                                    Spacer()
                                }
                                .foregroundStyle(.red)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal, 20)
                            
                            Button(role: .destructive) {
                                isDeleteAccountAlertPresented = true
                            } label: {
                                HStack {
                                    Image(systemName: "person.crop.circle.badge.xmark")
                                    Text("delete_account")
                                    Spacer()
                                }
                                .foregroundStyle(.red)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal, 20)
                            
                            Text("delete_account_warning")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }
                        
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.vertical, 32)
                }
            }
            .navigationTitle(String(localized: "settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .sheet(isPresented: $isEditNicknameSheetPresented) {
                EditNicknameView()
                    .environment(authVM)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: authVM.isAuthenticated) { oldValue, newValue in
                // 탈퇴 또는 로그아웃 시 자동으로 닫기
                if !newValue {
                    dismiss()
                }
            }
            .alert(String(localized: "logout"), isPresented: $isLogoutAlertPresented) {
                Button(String(localized: "cancel"), role: .cancel) { }
                Button(String(localized: "logout"), role: .destructive) {
                    authVM.signOut()
                    dismiss()
                }
            } message: {
                Text("logout_confirm")
            }
            .alert(String(localized: "delete_account_title"), isPresented: $isDeleteAccountAlertPresented) {
                Button(String(localized: "cancel"), role: .cancel) { }
                Button(String(localized: "delete_account"), role: .destructive) {
                    Task {
                        await authVM.deleteAccount(listViewModel: listVM)
                        dismiss()
                    }
                }
            } message: {
                Text("delete_account_message")
            }
        }
    }
    
    private func openSupportMail() {
        let subject = String(localized: "support_email_subject").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Shared%20List"
        guard let url = URL(string: "mailto:\(supportEmail)?subject=\(subject)") else { return }
        openURL(url)
    }
}

#Preview {
    SettingsView()
        .environment(AuthViewModel())
        .environment(ListViewModel())
}

