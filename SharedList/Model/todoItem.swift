//
//  TodoItem.swift
//  SharedList
//
//  Created by 박지호 on 11/12/25.
//

import Foundation

/// 개별 할 일 데이터 모델.
struct TodoItem: Identifiable, Codable, Equatable {
    /// Firestore 문서 ID.
    var id: String
    var title: String
    var subtitle: String?
    var isCompleted: Bool
    var dueDate: Date?
    
    init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil,
        isCompleted: Bool = false,
        dueDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.isCompleted = isCompleted
        self.dueDate = dueDate
    }
}
