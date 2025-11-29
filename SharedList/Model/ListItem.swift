//
//  ListItem.swift
//  SharedList
//
//  Created by 박지호 on 11/12/25.
//

import Foundation

/// 공유 리스트 데이터 모델.
struct ListItem: Identifiable, Codable, Equatable {
    /// Firestore 문서 ID. 필드가 없을 경우 문서 ID로 보완합니다.
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
    /// 공유용 초대 코드.
    var shareCode: String
    /// 공유된 사용자 UID 목록.
    var sharedUserIDs: [String]
    
    init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        todos: [TodoItem] = [],
        shareCode: String,
        sharedUserIDs: [String] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.todos = todos
        self.shareCode = shareCode
        self.sharedUserIDs = sharedUserIDs
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case isCompleted
        case dueDate
        case todos
        case shareCode
        case sharedUserIDs
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        todos = try container.decodeIfPresent([TodoItem].self, forKey: .todos) ?? []
        shareCode = try container.decodeIfPresent(String.self, forKey: .shareCode) ?? ""
        sharedUserIDs = try container.decodeIfPresent([String].self, forKey: .sharedUserIDs) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(todos, forKey: .todos)
        try container.encode(shareCode, forKey: .shareCode)
        try container.encode(sharedUserIDs, forKey: .sharedUserIDs)
    }
    
    static func == (lhs: ListItem, rhs: ListItem) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.isCompleted == rhs.isCompleted
            && lhs.dueDate == rhs.dueDate
            && lhs.todos == rhs.todos
            && lhs.shareCode == rhs.shareCode
            && lhs.sharedUserIDs == rhs.sharedUserIDs
    }
}
