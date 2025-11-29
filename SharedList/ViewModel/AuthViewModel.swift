//
//  AuthViewModel.swift
//  SharedList
//
//  Created by 박지호 on 11/12/25.
//

import Foundation
import SwiftUI
import AuthenticationServices
import Observation
import FirebaseFirestore
import FirebaseCore

/// 인증 상태를 관리하는 뷰모델.
@MainActor
@Observable
final class AuthViewModel {
    /// 인증 완료 여부.
    var isAuthenticated: Bool = false
    /// 사용자 ID (Apple ID).
    var userID: String = ""
    /// 사용자 닉네임.
    var nickname: String = ""
    /// 사용자 이메일.
    var userEmail: String = ""
    /// 닉네임 설정 완료 여부.
    var isNicknameSet: Bool = false
    /// 에러 메시지.
    var errorMessage: String?
    
    private var profilesCollection: CollectionReference? {
        guard FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore().collection("userProfiles")
    }
    
    init() {
        // UserDefaults에서 저장된 인증 상태 확인
        self.isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
        self.userID = UserDefaults.standard.string(forKey: "userID") ?? ""
        self.nickname = UserDefaults.standard.string(forKey: "nickname") ?? ""
        self.userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? ""
        self.isNicknameSet = UserDefaults.standard.bool(forKey: "isNicknameSet")
        
        if isAuthenticated && !userID.isEmpty {
            if nickname.isEmpty {
                Task {
                    await syncNicknameFromRemoteIfNeeded()
                }
            } else {
                Task {
                    await persistNicknameToServer(nickname)
                }
            }
        }
    }
    
    /// Sign in with Apple 요청 처리.
    /// - Parameter authorization: Apple 인증 결과
    func signInWithApple(authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = String(localized: "error_auth_failed")
            return
        }
        
        // 사용자 정보 저장
        userID = credential.user
        
        if let email = credential.email {
            userEmail = email
        }
        
        // UserDefaults에 저장
        UserDefaults.standard.set(true, forKey: "isAuthenticated")
        UserDefaults.standard.set(userID, forKey: "userID")
        UserDefaults.standard.set(userEmail, forKey: "userEmail")
        
        isAuthenticated = true
        errorMessage = nil
        
        // 닉네임이 설정되어 있지 않으면 닉네임 설정 화면으로 이동
        if !isNicknameSet {
            // 닉네임 설정 화면 표시는 View에서 처리
        }
        
        Task {
            await syncNicknameFromRemoteIfNeeded()
        }
    }
    
    /// 닉네임을 설정합니다.
    /// - Parameter nickname: 설정할 닉네임
    func setNickname(_ nickname: String) {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else {
            errorMessage = String(localized: "error_enter_nickname")
            return
        }
        
        cacheNickname(trimmedNickname)
        errorMessage = nil
        
        Task {
            await persistNicknameToServer(trimmedNickname)
        }
    }
    
    /// 로그아웃합니다.
    func signOut() {
        UserDefaults.standard.set(false, forKey: "isAuthenticated")
        UserDefaults.standard.removeObject(forKey: "userID")
        UserDefaults.standard.removeObject(forKey: "nickname")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.set(false, forKey: "isNicknameSet")
        
        isAuthenticated = false
        userID = ""
        nickname = ""
        userEmail = ""
        isNicknameSet = false
    }
    
    /// 계정을 삭제합니다. 모든 데이터를 초기화하고 로그아웃합니다.
    /// - Parameter listViewModel: 리스트 데이터를 초기화하기 위한 ViewModel
    func deleteAccount(listViewModel: ListViewModel) async {
        // 현재 userID 저장 (삭제 전에 사용)
        let currentUserID = userID
        
        // 1. Firestore에서 공유된 리스트에서 자신의 ID 제거 및 데이터 삭제
        if !currentUserID.isEmpty {
            await listViewModel.deleteAllData(userID: currentUserID)
        } else {
            // userID가 없어도 로컬 데이터는 초기화
            listViewModel.listItems.removeAll()
            listViewModel.isLoading = false
            listViewModel.errorMessage = nil
        }
        
        // 2. 모든 UserDefaults 데이터 삭제
        UserDefaults.standard.removeObject(forKey: "isAuthenticated")
        UserDefaults.standard.removeObject(forKey: "userID")
        UserDefaults.standard.removeObject(forKey: "nickname")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "isNicknameSet")
        
        // 3. 모든 상태 초기화
        isAuthenticated = false
        userID = ""
        nickname = ""
        userEmail = ""
        isNicknameSet = false
        errorMessage = nil
        
        // 4. UserDefaults 동기화 (즉시 반영)
        UserDefaults.standard.synchronize()
    }
    
    /// 원격 저장소에서 닉네임을 동기화합니다. (새 기기 로그인 대비)
    private func syncNicknameFromRemoteIfNeeded() async {
        guard nickname.isEmpty, !userID.isEmpty, let profilesCollection else { return }
        do {
            let snapshot = try await profilesCollection.document(userID).getDocument()
            if let remoteNickname = snapshot.data()?["nickname"] as? String {
                cacheNickname(remoteNickname)
            }
        } catch {
            print("⚠️ 닉네임 동기화 실패: \(error.localizedDescription)")
        }
    }
    
    /// 로컬 상태와 UserDefaults에 닉네임을 반영합니다.
    private func cacheNickname(_ nickname: String) {
        self.nickname = nickname
        let hasNickname = !nickname.isEmpty
        isNicknameSet = hasNickname
        UserDefaults.standard.set(nickname, forKey: "nickname")
        UserDefaults.standard.set(hasNickname, forKey: "isNicknameSet")
    }
    
    /// Firestore에 닉네임을 저장합니다.
    private func persistNicknameToServer(_ nickname: String) async {
        guard !userID.isEmpty, let profilesCollection else { return }
        do {
            try await profilesCollection.document(userID).setData(["nickname": nickname], merge: true)
        } catch {
            print("⚠️ 닉네임 저장 실패: \(error.localizedDescription)")
        }
    }
    
    /// 에러를 처리합니다.
    /// - Parameter error: 발생한 에러
    func handleError(_ error: Error) {
        #if DEBUG
        print("🔴 Sign in with Apple Error: \(error)")
        #endif
        
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                errorMessage = String(localized: "error_login_cancelled")
            case .failed:
                errorMessage = String(localized: "error_login_failed")
            case .invalidResponse:
                errorMessage = String(localized: "error_invalid_response")
            case .notHandled:
                errorMessage = String(localized: "error_request_failed")
            case .notInteractive:
                errorMessage = String(localized: "error_user_interaction_required")
            case .unknown:
                errorMessage = String(localized: "error_unknown")
            @unknown default:
                errorMessage = String(localized: "error_occurred")
            }
        } else {
            errorMessage = String(localized: "error_occurred")
        }
    }
}

