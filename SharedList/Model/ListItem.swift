//
//  ListItem.swift
//  SharedList
//
//  Created by 박지호 on 11/12/25.
//

import Foundation

/// 공유 리스트 데이터 모델.
struct ListItem: Identifiable, Codable, Equatable {
    /// Firestore 문서 ID.
    var id: String
    /// 리스트 제목.
    var title: String
    /// 부가 설명. 없을 수 있음.
    var subtitle: String?
    /// 리스트 완료 여부.
    var isCompleted: Bool
    /// 마감 기한. 없을 수 있음.
    var dueDate: Date?
    /// 리스트에 속한 할 일 아이템 배열.
    var todos: [TodoItem]
    /// 공유 링크(있다면 문자열 형태로 보관).
    var shareLink: String?
    /// 공유된 사용자 UID 목록.
    var sharedUserIDs: [String]
    
    init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        todos: [TodoItem] = [],
        shareLink: String? = nil,
        sharedUserIDs: [String] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.todos = todos
        self.shareLink = shareLink
        self.sharedUserIDs = sharedUserIDs
    }
}
