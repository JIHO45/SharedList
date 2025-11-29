//
//  ListViewModel.swift
//  SharedList
//
//  Created by 박지호 on 11/12/25.
//

import Foundation
import Observation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI
import FirebaseCore

/// 메인 리스트 화면의 상태를 관리하는 뷰모델.
@MainActor
@Observable
final class ListViewModel {
    /// 사용자가 소유하거나 공유받은 리스트 컬렉션.
    var listItems: [ListItem] = []
    /// 진행 중인 네트워크 작업 여부.
    var isLoading: Bool = false
    /// 사용자에게 표시할 에러 메시지.
    var errorMessage: String?
    
    /// Firestore 리스너를 저장하여 메모리 관리
    private var listener: ListenerRegistration?
    
    /// 리스너가 UI를 방해하지 못하게 막는 깃발
    private var isReordering: Bool = false
    
    /// 순서를 즉시 기억할 임시 저장소 (이게 있어야 안 튕김)
    private var localOrderCache: [String]?

    /// 사용자 닉네임 캐시 (userID -> nickname)
    private var nicknameCache: [String: String] = [:]
    
    /// 사용자 프로필이 저장된 Firestore 컬렉션
    private var profilesCollection: CollectionReference? {
        guard FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore().collection("userProfiles")
    }
    
    init() {
        // 개발용 더미 데이터는 제거 (실제 Firestore 데이터 사용)
    }
    
    /// Firestore에서 리스트를 실시간으로 관찰합니다.
    /// - Parameter userID: 현재 사용자 ID (AuthViewModel에서 가져옴)
    func observeLists(userID: String) {
            listener?.remove()
            
            guard !userID.isEmpty else {
                listItems = []
                return
            }
            
            // 캐시 초기화 (함수 시작 부분에 추가)
            if self.localOrderCache == nil {
                self.localOrderCache = loadListOrder(for: userID)
            }
            
            isLoading = true
            let db = Firestore.firestore()
            
            let query = db.collection("lists")
                .whereField("sharedUserIDs", arrayContains: userID)
            
            listener = query.addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    // ⭐ 핵심! 순서 변경 중이면 서버 데이터 무시 (튕김 방지)
                    if self.isReordering { return }
                    
                    if let error = error {
                        print("⚠️ 리스트 로드 오류: \(error.localizedDescription)")
                        self.errorMessage = String(localized: "error_loading_lists")
                        self.isLoading = false
                        return
                    }
                    
                    guard let snapshot = snapshot else {
                        self.isLoading = false
                        return
                    }
                    
                    // Firestore 데이터를 파싱
                    var newListItems: [ListItem] = []
                    var seenIDs = Set<String>()
                    
                    for document in snapshot.documents {
                        do {
                            let listItem = try self.parseListItem(from: document)
                            if !seenIDs.contains(listItem.id) {
                                seenIDs.insert(listItem.id)
                                newListItems.append(listItem)
                            }
                        } catch {
                            print("⚠️ 리스트 파싱 오류 (\(document.documentID)): \(error.localizedDescription)")
                        }
                    }
                    
                    // 1순위: 방금 내가 바꾼 순서(Cache), 2순위: 저장된 순서(UserDefaults)
                    let orderSource = self.localOrderCache ?? self.loadListOrder(for: userID) ?? []
                    
                    let sortedItems = newListItems.sorted { item1, item2 in
                        let index1 = orderSource.firstIndex(of: item1.id) ?? Int.max
                        let index2 = orderSource.firstIndex(of: item2.id) ?? Int.max
                        return index1 < index2
                    }
                    
                    // 최종 반영
                    self.listItems = sortedItems
                    self.isLoading = false
                    self.errorMessage = nil
                    
                    let uniqueUserIDs = Array(Set(newListItems.flatMap { $0.sharedUserIDs }))
                    if !uniqueUserIDs.isEmpty {
                        Task {
                            await self.ensureNicknames(for: uniqueUserIDs)
                        }
                    }
                    
                    // UserDefaults 정리: 삭제된 리스트 ID 제거
                    let currentListIDs = Set(newListItems.map { $0.id })
                    let cleanedOrder = orderSource.filter { currentListIDs.contains($0) }
                    if cleanedOrder.count != orderSource.count {
                        self.saveListOrder(cleanedOrder, for: userID)
                        self.localOrderCache = cleanedOrder
                    }
                }
            }
        }
    
    /// Firestore 문서를 ListItem으로 변환합니다.
    /// - Parameter document: Firestore 문서
    /// - Returns: 변환된 ListItem
    private func parseListItem(from document: QueryDocumentSnapshot) throws -> ListItem {
        let data = document.data()
        let documentID = document.documentID
        
        // 기본 필드 파싱
        let title = data["title"] as? String ?? ""
        let subtitle = data["subtitle"] as? String
        let isCompleted = data["isCompleted"] as? Bool ?? false
        let shareCode = data["shareCode"] as? String ?? ""
        let sharedUserIDs = data["sharedUserIDs"] as? [String] ?? []
        
        // Date 필드 파싱
        var dueDate: Date? = nil
        if let timestamp = data["dueDate"] as? Timestamp {
            dueDate = timestamp.dateValue()
        }
        
        // todos 배열 파싱
        var todos: [TodoItem] = []
        if let todosData = data["todos"] as? [[String: Any]] {
            for todoDict in todosData {
                if let todo = try? parseTodoItem(from: todoDict) {
                    todos.append(todo)
                }
            }
        }
        
        return ListItem(
            id: documentID,
            title: title,
            subtitle: subtitle,
            isCompleted: isCompleted,
            dueDate: dueDate,
            todos: todos,
            shareCode: shareCode,
            sharedUserIDs: sharedUserIDs
        )
    }
    
    /// Firestore 딕셔너리에서 TodoItem을 파싱합니다.
    /// - Parameter dict: Firestore 딕셔너리
    /// - Returns: 변환된 TodoItem
    private func parseTodoItem(from dict: [String: Any]) throws -> TodoItem {
        let id = dict["id"] as? String ?? UUID().uuidString
        let title = dict["title"] as? String ?? ""
        let subtitle = dict["subtitle"] as? String
        let isCompleted = dict["isCompleted"] as? Bool ?? false
        
        var dueDate: Date? = nil
        if let timestamp = dict["dueDate"] as? Timestamp {
            dueDate = timestamp.dateValue()
        }
        
        return TodoItem(
            id: id,
            title: title,
            subtitle: subtitle,
            isCompleted: isCompleted,
            dueDate: dueDate
        )
    }
    
    /// 리스너를 정리합니다. (메모리 누수 방지)
    func stopObserving() {
        listener?.remove()
        listener = nil
    }
    
    /// Firestore에서 리스트를 로드합니다. (하위 호환성을 위해 유지)
    /// - Note: 이제 `observeLists(userID:)`를 사용하세요.
    func loadLists() async {
        // 이 함수는 하위 호환성을 위해 유지하지만, 실제로는 observeLists를 사용해야 합니다.
        // SharedListView에서 observeLists를 직접 호출하도록 변경 필요
    }
    
    func dueDateText(for date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    /// 캐시된 사용자 닉네임을 반환합니다.
    /// - Parameter userID: Firestore 사용자 ID
    /// - Returns: 닉네임 문자열
    func displayName(for userID: String) -> String? {
        nicknameCache[userID]
    }
    
    /// Firestore에서 주어진 사용자들의 닉네임을 조회합니다.
    /// - Parameter userIDs: 닉네임이 필요한 사용자 ID 배열
    func ensureNicknames(for userIDs: [String]) async {
        guard let profilesCollection else { return }
        let normalizedIDs = Array(Set(userIDs)).filter { !$0.isEmpty && nicknameCache[$0] == nil }
        guard !normalizedIDs.isEmpty else { return }
        
        let batchSize = 10
        var index = 0
        
        while index < normalizedIDs.count {
            let endIndex = min(index + batchSize, normalizedIDs.count)
            let batch = Array(normalizedIDs[index..<endIndex])
            index = endIndex
            
            do {
                let snapshot = try await profilesCollection
                    .whereField(FieldPath.documentID(), in: batch)
                    .getDocuments()
                
                for document in snapshot.documents {
                    if let nickname = document.data()["nickname"] as? String {
                        nicknameCache[document.documentID] = nickname
                    }
                }
            } catch {
                print("⚠️ 사용자 닉네임 로드 실패: \(error.localizedDescription)")
            }
        }
    }
    
    /// 6자리 랜덤 코드를 생성합니다. (예: "A1B-2C3")
    private func createRandomCode(length: Int = 6) -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var code = ""
        for i in 0..<length {
            let randomChar = characters.randomElement()!
            code.append(randomChar)
            if i == length / 2 - 1 { // Add a dash in the middle
                code.append("-")
            }
        }
        return code
    }
    
    // 2. [참여자용] 초대 코드로 리스트 참여
    /// 초대 코드로 리스트에 참여합니다.
    /// - Parameters:
    ///   - code: 초대 코드
    ///   - userID: 현재 사용자 ID
    /// - Returns: 참여 성공 여부
    @MainActor
    func joinList(with code: String, userID: String) async -> Bool {
        self.isLoading = true
        defer { self.isLoading = false } // 함수가 끝나면 무조건 로딩 끔
        
        guard !userID.isEmpty else {
            self.errorMessage = String(localized: "error_no_user_id")
            return false
        }
        
        let db = Firestore.firestore()
        
        // 1. 해당 코드를 가진 리스트 찾기
        let query = db.collection("lists").whereField("shareCode", isEqualTo: code)
        
        do {
            let snapshot = try await query.getDocuments()
            
            guard let document = snapshot.documents.first else {
                self.errorMessage = String(localized: "error_invalid_invite_code")
                return false
            }
            
            let listID = document.documentID
            
            // 2. 이미 참여한 리스트인지 확인 (로컬 리스트 목록에서)
            if listItems.contains(where: { $0.id == listID }) {
                self.errorMessage = String(localized: "error_already_joined")
                return false
            }
            
            // 3. Firestore 문서에서 sharedUserIDs 확인
            let data = document.data()
            if let sharedUserIDs = data["sharedUserIDs"] as? [String] {
                // 4. 이미 참여한 사용자인지 확인
                if sharedUserIDs.contains(userID) {
                    self.errorMessage = String(localized: "error_already_joined")
                    return false
                }
            }
            
            // 5. 리스트의 'sharedUserIDs'에 내 ID 추가 (arrayUnion은 중복 방지됨)
            try await document.reference.updateData([
                "sharedUserIDs": FieldValue.arrayUnion([userID])
            ])
            
            // 6. 실시간 리스너가 자동으로 업데이트하므로 별도 새로고침 불필요
            
            return true
            
        } catch {
            print("Error joining list: \(error)")
            self.errorMessage = String(localized: "error_joining_list")
            return false
        }
    }
    
    /// 새로운 리스트를 생성하고 Firestore에 저장합니다.
    /// 공유 코드도 함께 자동 생성됩니다.
    /// - Parameters:
    ///   - title: 리스트 제목
    ///   - subtitle: 리스트 부제목 (선택사항)
    ///   - dueDate: 마감 기한 (선택사항)
    ///   - userID: 현재 사용자 ID
    @MainActor
    func createList(title: String, subtitle: String?, dueDate: Date?, userID: String) async {
        guard !userID.isEmpty else {
            errorMessage = String(localized: "error_no_user_id")
            return
        }
        
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = String(localized: "error_enter_title")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let db = Firestore.firestore()
        
        // 공유 코드 생성 (겹치지 않는 코드 찾기)
        var shareCode: String = ""
        for _ in 0..<5 {
            let newCode = createRandomCode(length: 6)
            let query = db.collection("lists").whereField("shareCode", isEqualTo: newCode)
            
            do {
                let snapshot = try await query.getDocuments()
                if snapshot.isEmpty {
                    shareCode = newCode
                    break
                }
            } catch {
                print("⚠️ 공유 코드 검사 중 오류: \(error.localizedDescription)")
            }
        }
        
        guard !shareCode.isEmpty else {
            errorMessage = String(localized: "error_share_code_failed")
            return
        }
        
        // 새 리스트 생성
        let newListItem = ListItem(
            title: title,
            subtitle: subtitle,
            dueDate: dueDate,
            todos: [],
            shareCode: shareCode,
            sharedUserIDs: [userID] // 생성자를 sharedUserIDs에 포함
        )
        
        do {
            // Firestore 문서 데이터 준비
            var listData: [String: Any] = [
                "title": newListItem.title,
                "isCompleted": newListItem.isCompleted,
                "todos": [],
                "shareCode": shareCode,
                "sharedUserIDs": [userID]
            ]
            
            if let subtitle = newListItem.subtitle {
                listData["subtitle"] = subtitle
            }
            
            if let dueDate = newListItem.dueDate {
                listData["dueDate"] = Timestamp(date: dueDate)
            }
            
            // Firestore에 저장
            _ = try await db.collection("lists").addDocument(data: listData)
            
            // 로컬 배열에 추가하지 않음 - 실시간 리스너가 자동으로 업데이트함
            // createList에서 추가하면 리스너가 같은 항목을 다시 추가하여 중복 발생 가능
            // 리스너가 빠르게 업데이트를 받으므로 사용자가 느끼지 못할 정도의 지연만 있음
            
        } catch {
            print("⚠️ 리스트 생성 중 Firestore 오류: \(error.localizedDescription)")
            errorMessage = String(localized: "error_creating_list")
        }
    }
    
    /// 리스트 정보를 수정합니다.
    /// - Parameters:
    ///   - listID: 수정할 리스트 ID
    ///   - title: 새 제목
    ///   - subtitle: 새 부제목 (선택사항)
    ///   - dueDate: 새 마감 기한 (선택사항)
    @MainActor
    func updateList(listID: String, title: String, subtitle: String?, dueDate: Date?) async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = String(localized: "error_enter_title")
            return
        }
        
        let db = Firestore.firestore()
        let listRef = db.collection("lists").document(listID)
        
        do {
            // 업데이트할 데이터 준비
            var updateData: [String: Any] = [
                "title": title
            ]
            
            if let subtitle = subtitle {
                updateData["subtitle"] = subtitle
            } else {
                updateData["subtitle"] = FieldValue.delete()
            }
            
            if let dueDate = dueDate {
                updateData["dueDate"] = Timestamp(date: dueDate)
            } else {
                updateData["dueDate"] = FieldValue.delete()
            }
            
            // Firestore 업데이트
            try await listRef.updateData(updateData)
            
            // 로컬 배열도 업데이트 (즉시 UI 반영)
            if let index = listItems.firstIndex(where: { $0.id == listID }) {
                listItems[index].title = title
                listItems[index].subtitle = subtitle
                listItems[index].dueDate = dueDate
            }
            
            print("✅ 리스트 \(listID) 수정 완료")
        } catch {
            print("⚠️ 리스트 수정 중 Firestore 오류: \(error.localizedDescription)")
            errorMessage = String(localized: "error_updating_list")
        }
    }
    
    /// 특정 리스트에 할 일을 추가합니다.
    /// - Parameters:
    ///   - todo: 추가할 할 일 아이템
    ///   - listID: 리스트 ID
    @MainActor
    func addTodo(_ todo: TodoItem, to listID: String) async {
        guard let index = listItems.firstIndex(where: { $0.id == listID }) else { return }
        
        // 1. 로컬 배열에 추가 (즉시 UI 업데이트)
        listItems[index].todos.append(todo)
        
        // 2. Firestore에 저장
        let db = Firestore.firestore()
        let listRef = db.collection("lists").document(listID)
        
        do {
            // TodoItem을 딕셔너리로 변환
            var todoDict: [String: Any] = [
                "id": todo.id,
                "title": todo.title,
                "isCompleted": todo.isCompleted
            ]
            
            if let subtitle = todo.subtitle {
                todoDict["subtitle"] = subtitle
            }
            
            if let dueDate = todo.dueDate {
                todoDict["dueDate"] = Timestamp(date: dueDate)
            }
            
            // todos 배열에 추가
            try await listRef.updateData([
                "todos": FieldValue.arrayUnion([todoDict])
            ])
        } catch {
            print("⚠️ Todo 추가 중 Firestore 오류: \(error.localizedDescription)")
            // 에러 발생 시 로컬에서도 제거 (롤백)
            if let todoIndex = listItems[index].todos.firstIndex(where: { $0.id == todo.id }) {
                listItems[index].todos.remove(at: todoIndex)
            }
            errorMessage = String(localized: "error_adding_todo")
        }
    }
    
    /// 특정 할 일의 내용을 수정합니다.
    /// - Parameters:
    ///   - listID: 리스트 ID
    ///   - todoID: 수정할 할 일 ID
    ///   - title: 새 제목
    ///   - subtitle: 새 부제목
    ///   - dueDate: 새 마감일
    @MainActor
    func updateTodo(
        in listID: String,
        todoID: String,
        title: String,
        subtitle: String?,
        dueDate: Date?
    ) async {
        guard let listIndex = listItems.firstIndex(where: { $0.id == listID }),
              let todoIndex = listItems[listIndex].todos.firstIndex(where: { $0.id == todoID }) else { return }
        
        // 로컬 데이터 즉시 반영
        listItems[listIndex].todos[todoIndex].title = title
        listItems[listIndex].todos[todoIndex].subtitle = subtitle
        listItems[listIndex].todos[todoIndex].dueDate = dueDate
        
        let db = Firestore.firestore()
        let listRef = db.collection("lists").document(listID)
        
        do {
            let todosData = listItems[listIndex].todos.map { todo -> [String: Any] in
                var todoDict: [String: Any] = [
                    "id": todo.id,
                    "title": todo.title,
                    "isCompleted": todo.isCompleted
                ]
                
                if let subtitle = todo.subtitle {
                    todoDict["subtitle"] = subtitle
                }
                
                if let dueDate = todo.dueDate {
                    todoDict["dueDate"] = Timestamp(date: dueDate)
                }
                
                return todoDict
            }
            
            try await listRef.updateData(["todos": todosData])
        } catch {
            print("⚠️ Todo 수정 중 Firestore 오류: \(error.localizedDescription)")
            errorMessage = String(localized: "error_updating_todo")
        }
    }
    
    /// 특정 리스트의 할 일 순서를 업데이트합니다.
    /// - Parameters:
    ///   - todos: 새로운 순서의 할 일 배열
    ///   - listID: 리스트 ID
    @MainActor
    func updateTodoOrder(todos: [TodoItem], in listID: String) async {
        guard let listIndex = listItems.firstIndex(where: { $0.id == listID }) else { return }
        
        // 로컬 상태 업데이트
        listItems[listIndex].todos = todos
        
        // Firestore에 저장
        let db = Firestore.firestore()
        let listRef = db.collection("lists").document(listID)
        
        do {
            // TodoItem 배열을 딕셔너리 배열로 변환
            let todosData = todos.map { todo -> [String: Any] in
                var todoDict: [String: Any] = [
                    "id": todo.id,
                    "title": todo.title,
                    "isCompleted": todo.isCompleted
                ]
                
                if let subtitle = todo.subtitle {
                    todoDict["subtitle"] = subtitle
                }
                
                if let dueDate = todo.dueDate {
                    todoDict["dueDate"] = Timestamp(date: dueDate)
                }
                
                return todoDict
            }
            
            // 전체 todos 배열을 교체
            try await listRef.updateData([
                "todos": todosData
            ])
        } catch {
            print("⚠️ Todo 순서 업데이트 중 Firestore 오류: \(error.localizedDescription)")
            errorMessage = String(localized: "error_reordering_todo")
        }
    }
    
    /// 선택된 할 일들을 삭제합니다.
    /// - Parameters:
    ///   - todoIDs: 삭제할 할 일 ID 배열
    ///   - listID: 리스트 ID
    @MainActor
    func deleteTodos(todoIDs: [String], in listID: String) async {
        guard let listIndex = listItems.firstIndex(where: { $0.id == listID }) else { return }
        
        // 로컬에서 제거
        listItems[listIndex].todos.removeAll { todoIDs.contains($0.id) }
        
        // Firestore에 저장
        let db = Firestore.firestore()
        let listRef = db.collection("lists").document(listID)
        
        do {
            // TodoItem 배열을 딕셔너리 배열로 변환
            let todosData = listItems[listIndex].todos.map { todo -> [String: Any] in
                var todoDict: [String: Any] = [
                    "id": todo.id,
                    "title": todo.title,
                    "isCompleted": todo.isCompleted
                ]
                
                if let subtitle = todo.subtitle {
                    todoDict["subtitle"] = subtitle
                }
                
                if let dueDate = todo.dueDate {
                    todoDict["dueDate"] = Timestamp(date: dueDate)
                }
                
                return todoDict
            }
            
            // 전체 todos 배열을 교체
            try await listRef.updateData([
                "todos": todosData
            ])
        } catch {
            print("⚠️ Todo 삭제 중 Firestore 오류: \(error.localizedDescription)")
            errorMessage = String(localized: "error_deleting_todo")
        }
    }
    
    /// 리스트를 완료 처리하고 삭제합니다.
    /// - Parameters:
    ///   - listID: 완료할 리스트 ID
    ///   - userID: 사용자 ID (UserDefaults 순서 정리용)
    @MainActor
    func completeList(listID: String, userID: String) async {
        let db = Firestore.firestore()
        let listRef = db.collection("lists").document(listID)
        
        do {
            // Firestore에서 리스트 삭제
            try await listRef.delete()
            
            // 로컬에서도 제거 (실시간 리스너가 자동으로 업데이트하지만 즉시 반영)
            listItems.removeAll { $0.id == listID }
            
            // localOrderCache에서도 제거
            localOrderCache?.removeAll { $0 == listID }
            
            // UserDefaults에서 순서 업데이트 (삭제된 리스트 ID 제거)
            if let currentOrder = loadListOrder(for: userID) {
                let updatedOrder = currentOrder.filter { $0 != listID }
                saveListOrder(updatedOrder, for: userID)
            }
            
            print("✅ 리스트 \(listID) 완료 및 삭제됨")
        } catch {
            print("⚠️ 리스트 완료 중 오류: \(error.localizedDescription)")
            errorMessage = String(localized: "error_completing_list")
        }
    }
    
    /// 특정 리스트의 할 일 완료 상태를 토글합니다.
    /// - Parameters:
    ///   - todoID: 할 일 ID
    ///   - listID: 리스트 ID
    @MainActor
    func toggleTodoCompletion(todoID: String, in listID: String) async {
        guard let listIndex = listItems.firstIndex(where: { $0.id == listID }),
              let todoIndex = listItems[listIndex].todos.firstIndex(where: { $0.id == todoID }) else { return }
        
        // 1. 로컬 상태 변경 (즉시 UI 업데이트)
        let oldValue = listItems[listIndex].todos[todoIndex].isCompleted
        listItems[listIndex].todos[todoIndex].isCompleted.toggle()
        
        // 2. Firestore에 저장
        let db = Firestore.firestore()
        let listRef = db.collection("lists").document(listID)
        
        do {
            // 현재 todos 배열 전체를 가져와서 해당 todo만 업데이트
            let currentTodos = listItems[listIndex].todos
            
            // todos 배열을 딕셔너리 배열로 변환
            var todosArray: [[String: Any]] = []
            for todo in currentTodos {
                var todoDict: [String: Any] = [
                    "id": todo.id,
                    "title": todo.title,
                    "isCompleted": todo.isCompleted
                ]
                
                if let subtitle = todo.subtitle {
                    todoDict["subtitle"] = subtitle
                }
                
                if let dueDate = todo.dueDate {
                    todoDict["dueDate"] = Timestamp(date: dueDate)
                }
                
                todosArray.append(todoDict)
            }
            
            // 전체 todos 배열을 업데이트
            try await listRef.updateData([
                "todos": todosArray
            ])
        } catch {
            print("⚠️ Todo 완료 상태 변경 중 Firestore 오류: \(error.localizedDescription)")
            // 에러 발생 시 원래 상태로 롤백
            listItems[listIndex].todos[todoIndex].isCompleted = oldValue
            errorMessage = String(localized: "error_toggling_completion")
        }
    }
        
    /// 리스트의 완료 진행률을 계산합니다.
    /// - Parameter item: 리스트 아이템
    /// - Returns: 완료 진행률 (0.0 ~ 1.0)
    func completionProgress(for item: ListItem) -> Double {
        let completedCount = item.todos.filter { $0.isCompleted }.count
        let totalCount = item.todos.count
        return totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
    }
    
    /// 리스트의 완료 퍼센트 뱃지 View를 반환합니다 (작은 버전, navigationTitle용).
    /// - Parameter item: 리스트 아이템
    /// - Returns: 퍼센트만 표시하는 작은 뱃지 View
    func compactCompletionBadge(for item: ListItem) -> some View {
        let progress = completionProgress(for: item)
        return ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 32, height: 32)
            Text("\(Int(progress * 100))%")
                .font(.caption2.bold())
                .foregroundStyle(.primary)
        }
    }
    
    /// 리스트의 완료 뱃지 View를 반환합니다 (큰 버전, 리스트 카드용).
    /// - Parameter item: 리스트 아이템
    /// - Returns: 퍼센트와 완료 수를 표시하는 뱃지 View
    func completionBadge(for item: ListItem) -> some View {
        let completedCount = item.todos.filter { $0.isCompleted }.count
        let totalCount = item.todos.count
        let progress = completionProgress(for: item)
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 32, height: 32)
                Text("\(Int(progress * 100))%")
                    .font(.caption2.bold())
                    .foregroundStyle(.primary)
            }
            Text("completed_\(completedCount)_of_\(totalCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    /// 모든 리스트 데이터를 삭제합니다. (계정 탈퇴 시 사용)
    /// - Parameter userID: 삭제할 사용자 ID
    @MainActor
    func deleteAllData(userID: String) async {
        guard !userID.isEmpty else {
            // userID가 비어있으면 로컬 데이터만 초기화
            listItems.removeAll()
            isLoading = false
            errorMessage = nil
            return
        }
        
        let db = Firestore.firestore()
        
        do {
            // 1. 자신이 참여한 모든 리스트 찾기
            let query = db.collection("lists").whereField("sharedUserIDs", arrayContains: userID)
            let snapshot = try await query.getDocuments()
            
            // 2. 각 리스트의 sharedUserIDs 배열에서 자신의 ID 제거
            // 배치 처리로 모든 업데이트를 동시에 실행
            await withTaskGroup(of: Void.self) { group in
                for document in snapshot.documents {
                    group.addTask {
                        do {
                            try await document.reference.updateData([
                                "sharedUserIDs": FieldValue.arrayRemove([userID])
                            ])
                        } catch {
                            // 개별 문서 업데이트 실패는 로그만 남기고 계속 진행
                            print("⚠️ 리스트 \(document.documentID)에서 사용자 제거 실패: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            // 3. 로컬 데이터 초기화 (Firestore 작업 성공 여부와 관계없이 실행)
            listItems.removeAll()
            isLoading = false
            errorMessage = nil
            
        } catch {
            // Firestore 쿼리 실패 시에도 로컬 데이터는 초기화
            print("⚠️ 계정 삭제 중 Firestore 쿼리 오류: \(error.localizedDescription)")
            listItems.removeAll()
            isLoading = false
            errorMessage = nil
        }
        
        // UserDefaults에서 순서 정보 삭제
        let key = "listOrder_\(userID)"
        UserDefaults.standard.removeObject(forKey: key)
        
        // localOrderCache 초기화
        localOrderCache = nil
    }
    
    // MARK: - 리스트 순서 관리 (로컬 전용)
    
    /// 사용자별 리스트 순서를 UserDefaults에 저장합니다.
    /// 순서는 공유되지 않으며, 각 사용자의 기기에만 저장됩니다.
    /// - Parameters:
    ///   - listIDs: 리스트 ID 배열 (순서 포함)
    ///   - userID: 사용자 ID
    private func saveListOrder(_ listIDs: [String], for userID: String) {
        let key = "listOrder_\(userID)"
        UserDefaults.standard.set(listIDs, forKey: key)
    }
    
    /// UserDefaults에서 저장된 리스트 순서를 가져옵니다.
    /// - Parameter userID: 사용자 ID
    /// - Returns: 리스트 ID 배열 (순서 포함), 없으면 nil
    private func loadListOrder(for userID: String) -> [String]? {
        let key = "listOrder_\(userID)"
        return UserDefaults.standard.array(forKey: key) as? [String]
    }
    
    /// 드래그 시작 시 호출할 함수
    @MainActor
    func startReordering() {
        self.isReordering = true
    }
    
    /// 리스트 순서를 업데이트하고 저장합니다 (로컬에만 저장).
    /// onMove에서 호출되며, Firestore에는 저장하지 않습니다.
    /// - Parameter userID: 사용자 ID
    @MainActor
    func updateListOrder(userID: String) {
        // 1. 현재 화면에 보이는 순서대로 ID를 추출
        let listIDs = listItems.map { $0.id }
        
        // 2. 메모리 캐시에 즉시 저장 (UI가 즉시 반응하게 함)
        self.localOrderCache = listIDs
        
        // 3. 파일(UserDefaults)에 저장 (앱 껐다 켜도 유지되게 함)
        saveListOrder(listIDs, for: userID)
        
        // 4. 리스너 차단 해제 (약간의 딜레이를 줘서 안전하게)
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초 대기
            self.isReordering = false
        }
    }
    
    // MARK: - 리스트 삭제 (나가기)
    
    /// 선택된 리스트들에서 사용자를 제거합니다.
    /// 리스트에 아무도 없으면 Firestore에서도 리스트를 삭제합니다.
    /// - Parameters:
    ///   - listIDs: 삭제할 리스트 ID 배열
    ///   - userID: 사용자 ID
    @MainActor
    func leaveLists(listIDs: [String], userID: String) async {
        guard !userID.isEmpty, !listIDs.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let db = Firestore.firestore()
        
        // 배치 처리로 모든 리스트 업데이트/삭제를 동시에 실행
        await withTaskGroup(of: Void.self) { group in
            for listID in listIDs {
                group.addTask {
                    do {
                        let listRef = db.collection("lists").document(listID)
                        
                        // 현재 리스트 데이터 가져오기
                        let document = try await listRef.getDocument()
                        
                        guard document.exists,
                              let data = document.data(),
                              var sharedUserIDs = data["sharedUserIDs"] as? [String] else {
                            print("⚠️ 리스트 \(listID) 데이터를 찾을 수 없습니다.")
                            return
                        }
                        
                        // 사용자 ID 제거
                        sharedUserIDs.removeAll { $0 == userID }
                        
                        if sharedUserIDs.isEmpty {
                            // 아무도 없으면 리스트 삭제
                            try await listRef.delete()
                            print("✅ 리스트 \(listID) 삭제 완료 (사용자 없음)")
                        } else {
                            // 다른 사용자가 있으면 sharedUserIDs만 업데이트
                            try await listRef.updateData([
                                "sharedUserIDs": sharedUserIDs
                            ])
                            print("✅ 리스트 \(listID)에서 사용자 제거 완료")
                        }
                    } catch {
                        print("⚠️ 리스트 \(listID) 처리 중 오류: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // 로컬에서도 제거 (실시간 리스너가 자동으로 업데이트하지만 즉시 반영)
        listItems.removeAll { listIDs.contains($0.id) }
        
        // localOrderCache에서도 제거
        localOrderCache?.removeAll { listIDs.contains($0) }
        
        // UserDefaults에서 순서 업데이트 (삭제된 리스트 ID 제거)
        if let currentOrder = loadListOrder(for: userID) {
            let updatedOrder = currentOrder.filter { !listIDs.contains($0) }
            saveListOrder(updatedOrder, for: userID)
        }
        
        errorMessage = nil
    }
}
