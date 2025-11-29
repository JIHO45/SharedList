//
//  ListDetailView.swift
//  SharedList
//
//  Created by 박지호 on 11/17/25.
//

import SwiftUI
import UIKit

struct ListDetailView: View {
    @Environment(ListViewModel.self) var listVM
    @Environment(AuthViewModel.self) var authVM
    @Environment(\.dismiss) private var dismiss
    
    @Binding var listItem: ListItem
    
    @State private var shareStatusMessage: String?
    @State private var isShareActivitySheetPresented = false
    @State private var shareActivityItems: [Any] = []
    @State private var selectedTodoIDs: Set<String> = []
    
    @State private var isAddTodoSheetPresented = false
    @State private var editingTodo: TodoItem? = nil
    @State private var isShareSheetPresented = false
    @State private var isEditMode: Bool = false
    @State private var isDeleteAlertPresented = false
    @State private var isCompleteAlertPresented: Bool = false
    @State private var isCompletedExpanded: Bool = true
    
    /// 미완료 할 일 목록
    private var incompleteTodos: [TodoItem] {
        listItem.todos.filter { !$0.isCompleted }
    }
    
    /// 완료된 할 일 목록
    private var completedTodos: [TodoItem] {
        listItem.todos.filter { $0.isCompleted }
    }
    
    private let gradient = LinearGradient(
        colors: [Color.green.opacity(0.25), Color.teal.opacity(0.35), Color.black.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            gradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 커스텀 Navigation Bar
                customNavigationBar
                
                if listItem.todos.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        String(localized: "empty_todo_title"),
                        systemImage: "checklist",
                        description: Text("empty_todo_description")
                    )
                    .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    if let subtitle = listItem.subtitle {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(subtitle)
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    
                    Divider()
                        .frame(height: 1)
                        .background(.secondary)
                        .padding(.horizontal)
                    
                    List {
                        // 미완료 할 일 섹션
                        if !incompleteTodos.isEmpty {
                            Section(String(localized: "incomplete_items_\(incompleteTodos.count)")) {
                                ForEach(incompleteTodos, id: \.id) { todo in
                                    if let index = listItem.todos.firstIndex(where: { $0.id == todo.id }) {
                                        todoRow(for: todo, at: index)
                                            .listRowInsets(EdgeInsets(top: 9, leading: 20, bottom: 9, trailing: 20))
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                    }
                                }
                                .onMove { source, destination in
                                    if isEditMode {
                                        var incomplete = incompleteTodos
                                        incomplete.move(fromOffsets: source, toOffset: destination)
                                        listItem.todos = incomplete + completedTodos
                                        Task {
                                            await listVM.updateTodoOrder(todos: listItem.todos, in: listItem.id)
                                        }
                                    }
                                }
                            }
                            .listSectionSeparator(.hidden)
                        }
                        
                        // 완료된 할 일 섹션 (접기 가능)
                        if !completedTodos.isEmpty {
                            Section(String(localized: "completed_items_\(completedTodos.count)"), isExpanded: $isCompletedExpanded) {
                                ForEach(completedTodos, id: \.id) { todo in
                                    if let index = listItem.todos.firstIndex(where: { $0.id == todo.id }) {
                                        todoRow(for: todo, at: index)
                                            .listRowInsets(EdgeInsets(top: 9, leading: 20, bottom: 9, trailing: 20))
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                    }
                                }
                                .onMove { source, destination in
                                    if isEditMode {
                                        var complete = completedTodos
                                        complete.move(fromOffsets: source, toOffset: destination)
                                        listItem.todos = incompleteTodos + complete
                                        Task {
                                            await listVM.updateTodoOrder(todos: listItem.todos, in: listItem.id)
                                        }
                                    }
                                }
                            }
                            .listSectionSeparator(.hidden)
                        }
                    }
                    .listStyle(.sidebar)
                    .listSectionSeparator(.hidden)
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, Binding(
                        get: { isEditMode ? .active : .inactive },
                        set: { newValue in
                            isEditMode = (newValue == .active)
                        }
                    ))
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                
                // 설정 메뉴 (편집 모드에 따라 내용만 변경)
                Menu {
                    if isEditMode {
                        Button {
                            isEditMode = false
                            selectedTodoIDs.removeAll()
                        } label: {
                            Label(String(localized: "done_editing"), systemImage: "checkmark")
                        }
                    } else {
                        Button {
                            isCompleteAlertPresented = true
                        } label: {
                            Label(String(localized: "complete_list"), systemImage: "checkmark.circle")
                        }
                        
                        Button {
                            isEditMode = true
                        } label: {
                            Label(String(localized: "edit"), systemImage: "pencil")
                        }
                        .disabled(listItem.todos.isEmpty)
                    }
                } label: {
                    Image(systemName: isEditMode ? "checkmark.circle.fill" : "gear")
                        .foregroundStyle(isEditMode ? .green : .primary)
                }
                
                // 추가 버튼 (편집 모드에서는 숨김)
                Button {
                    editingTodo = nil
                    isAddTodoSheetPresented = true
                } label: {
                    Label(String(localized: "add"), systemImage: "plus")
                }
                .opacity(isEditMode ? 0 : 1)
                .disabled(isEditMode)
            }
        }
        .sheet(isPresented: $isAddTodoSheetPresented) {
            Add_EditTodoSheetView(
                listItem: $listItem,
                selectedTodoIDs: $selectedTodoIDs,
                editingTodo: editingTodo
            )
                .presentationDetents([.fraction(0.7), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShareSheetPresented) {
            shareSheetContent
                .environment(authVM)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: isAddTodoSheetPresented) { _ , newValue in
            if !newValue {
                editingTodo = nil
            }
        }
        .alert(String(localized: "delete_list_title"), isPresented: $isDeleteAlertPresented) {
            Button(String(localized: "cancel"), role: .cancel) { }
            Button(String(localized: "delete"), role: .destructive) {
                Task {
                    if isEditMode && !selectedTodoIDs.isEmpty {
                        // Todo 삭제
                        let todoIDs = Array(selectedTodoIDs)
                        await listVM.deleteTodos(todoIDs: todoIDs, in: listItem.id)
                        selectedTodoIDs.removeAll()
                        isEditMode = false
                    } else {
                        // 리스트에서 나가기
                        await listVM.leaveLists(listIDs: [listItem.id], userID: authVM.userID)
                        isEditMode = false
                    }
                }
            }
        } message: {
            if isEditMode && !selectedTodoIDs.isEmpty {
                Text("delete_todo_message_\(selectedTodoIDs.count)")
            } else {
                Text("leave_list_message")
            }
        }
        .alert(String(localized: "complete_list_title"), isPresented: $isCompleteAlertPresented) {
            Button(String(localized: "cancel"), role: .cancel) { }
            Button(String(localized: "complete")) {
                Task {
                    await listVM.completeList(listID: listItem.id, userID: authVM.userID)
                    dismiss()
                }
            }
        } message: {
            Text("complete_list_message")
        }
        .alert(String(localized: "error"), isPresented: Binding(
            get: { listVM.errorMessage != nil },
            set: { value in
                if !value { listVM.errorMessage = nil }
            }
        )) {
            Button(String(localized: "confirm"), role: .cancel) { }
        } message: {
            Text(listVM.errorMessage ?? String(localized: "unknown_error_occurred"))
        }
    }
    
    @ViewBuilder
    private func todoRow(for todo: TodoItem, at index: Int) -> some View {
            HStack {
            if isEditMode {
                Button {
                    if selectedTodoIDs.contains(todo.id) {
                        selectedTodoIDs.remove(todo.id)
                    } else {
                        selectedTodoIDs.insert(todo.id)
                    }
                } label: {
                    Image(systemName: selectedTodoIDs.contains(todo.id) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selectedTodoIDs.contains(todo.id) ? .green : .secondary)
                        .frame(width: 32, height: 32)
                }
            }
            
            HStack(spacing: 12) {
                if !isEditMode {
                    Button {
                        Task {
                            await listVM.toggleTodoCompletion(todoID: todo.id, in: listItem.id)
                        }
                    } label: {
                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(todo.isCompleted ? .green : .secondary)
                            .frame(width: 32, height: 32)
                    }
                    .disabled(isEditMode)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.title)
                        .font(.headline)
                        .strikethrough(todo.isCompleted)
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    if let subtitle = todo.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if let dueText = listVM.dueDateText(for: todo.dueDate) {
                    Text(dueText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(thinMartialRoundedRectangleModifier())
            .opacity(todo.isCompleted ? 0.6 : 1.0)
        }
    }
    
    /// 공유 사용자 표시에 사용할 닉네임을 반환합니다.
    private func sharedUserDisplayName(for userID: String) -> String {
        if userID == authVM.userID {
            return authVM.nickname.isEmpty ? String(localized: "me") : authVM.nickname
        }
        return listVM.displayName(for: userID) ?? userID
    }
    
    @ViewBuilder
    private var shareSheetContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("share_list")
                .font(.title3)
            
            Divider()

            if listItem.sharedUserIDs.isEmpty {
                Text("no_shared_users")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("shared_users")
                    .font(.subheadline.bold())
                ForEach(listItem.sharedUserIDs, id: \.self) { userID in
                    HStack {
                        Image(systemName: "person.crop.circle")
                        Text(sharedUserDisplayName(for: userID))
                            .font(.subheadline)
                    }
                }
            }
            
            Divider()
            
            // 공유 코드는 리스트 생성 시 자동으로 생성되므로 항상 표시
            if !listItem.shareCode.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(String(localized: "invite_code"), systemImage: "number.circle")
                    Spacer()
                        Text(listItem.shareCode)
                        .font(.callout.monospaced())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    Button {
                            UIPasteboard.general.string = listItem.shareCode
                        shareStatusMessage = String(localized: "code_copied")
                    } label: {
                            Image(systemName: "square.on.square")
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            if let message = shareStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(30)
        .environment(listVM)
        .sheet(isPresented: $isShareActivitySheetPresented) {
            ShareActivityView(activityItems: shareActivityItems)
        }
        .task {
            await listVM.ensureNicknames(for: listItem.sharedUserIDs)
        }
    }
    
}

private extension ListDetailView {
    /// 커스텀 Navigation Bar
    var customNavigationBar: some View {
        ZStack {
            // 중앙 타이틀
            Text(listItem.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
            
            // 좌우 버튼
            HStack {
                // 뒤로가기 버튼
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                        Text("back")
                            .font(.body)
                    }
                    .foregroundStyle(.white)
                }
                
                Spacer()
                
                // 우측 버튼들
                HStack(spacing: 20) {
                    if isEditMode {
                        // 수정 버튼
                        Button {
                            if let selectedID = selectedTodoIDs.first,
                               let todo = listItem.todos.first(where: { $0.id == selectedID }) {
                                editingTodo = todo
                                isAddTodoSheetPresented = true
                            }
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.body)
                                .foregroundStyle(selectedTodoIDs.count == 1 ? .white : .white.opacity(0.4))
                        }
                        .disabled(selectedTodoIDs.count != 1)
                        
                        // 삭제 버튼
                        Button {
                            isDeleteAlertPresented = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.body)
                                .foregroundStyle(selectedTodoIDs.isEmpty ? .white.opacity(0.4) : Color.red)
                        }
                        .disabled(selectedTodoIDs.isEmpty)
                    } else {
                        // 공유 버튼
                        shareToolbarButton
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
    
    @ViewBuilder
    var shareToolbarButton: some View {
        Button {
            isShareSheetPresented = true
        } label: {
            Group {
                if listItem.sharedUserIDs.isEmpty {
                    Image(systemName: "square.and.arrow.up")
                } else if listItem.sharedUserIDs.count == 1 {
                    Image(systemName: "person.fill")
                } else if listItem.sharedUserIDs.count == 2 {
                    Image(systemName: "person.2.fill")
                } else {
                    Image(systemName: "person.3.fill")
                }
            }
            .font(.body)
            .foregroundStyle(.white)
        }
    }
}

/// iOS 기본 공유 시트를 SwiftUI에서 사용하기 위한 래퍼
struct ShareActivityView: UIViewControllerRepresentable {
        let activityItems: [Any]
        let applicationActivities: [UIActivity]? = nil
        
        func makeUIViewController(context: Context) -> UIActivityViewController {
            let controller = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: applicationActivities
            )
            return controller
        }
        
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // 업데이트 불필요
    }
}


struct Add_EditTodoSheetView : View {
    @Environment(ListViewModel.self) private var listVM
    @Environment(\.dismiss) private var dismiss
    @Binding private var listItem: ListItem
    @Binding private var selectedTodoIDs: Set<String>
    
    private let editingTodoID: String?
    
    @State private var title: String
    @State private var subtitle: String?
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool
    
    private var isEditMode: Bool { editingTodoID != nil }
    
    init(
        listItem: Binding<ListItem>,
        selectedTodoIDs: Binding<Set<String>>,
        editingTodo: TodoItem? = nil
    ) {
        _listItem = listItem
        _selectedTodoIDs = selectedTodoIDs
        editingTodoID = editingTodo?.id
        _title = State(initialValue: editingTodo?.title ?? "")
        _subtitle = State(initialValue: editingTodo?.subtitle)
        _dueDate = State(initialValue: editingTodo?.dueDate)
        _hasDueDate = State(initialValue: editingTodo?.dueDate != nil)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section {
                        VStack(alignment: .leading) {
                            Text("title")
                            TextField(String(localized: "enter_title"), text: $title)
                        }
                        VStack(alignment: .leading) {
                            Text("subtitle")
                            TextField(String(localized: "enter_subtitle"), text: Binding(
                                get: { subtitle ?? "" }, // 값이 nil이면 빈 칸으로 보여줌
                                set: { subtitle = $0.isEmpty ? nil : $0 } // 빈 칸이면 nil로 저장
                            ))
                        }
                    }
                    
                    Section {
                        Toggle(String(localized: "set_due_date"), isOn: Binding(
                            get: { hasDueDate },
                            set: { newValue in
                                hasDueDate = newValue
                                if newValue {
                                    // Toggle이 켜질 때 dueDate가 nil이면 오늘 날짜로 설정
                                    if dueDate == nil {
                                        dueDate = Date()
                                    }
                                } else {
                                    // Toggle이 꺼지면 dueDate를 nil로 설정
                                    dueDate = nil
                                }
                            }
                        ))
                        
                        if hasDueDate {
                            DatePicker(
                                String(localized: "due_date"),
                                selection: Binding(
                                    get: { dueDate ?? Date() },
                                    set: { dueDate = $0 }),
                                in: Date()...,
                                displayedComponents: [.date])
                        }
                    }
                }
                Button {
                    Task {
                        let normalizedDueDate = hasDueDate ? dueDate : nil
                        if let todoID = editingTodoID {
                            await listVM.updateTodo(
                                in: listItem.id,
                                todoID: todoID,
                                title: title,
                                subtitle: subtitle,
                                dueDate: normalizedDueDate
                            )
                        } else {
                            let newTodo = TodoItem(
                                title: title,
                                subtitle: subtitle,
                                dueDate: normalizedDueDate
                            )
                            await listVM.addTodo(newTodo, to: listItem.id)
                        }
                        selectedTodoIDs.removeAll()
                        dismiss()
                    }
                } label: {
                    Text(isEditMode ? "save" : "confirm")
                        .foregroundStyle(Color.white)
                        .padding(.vertical)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding()
                }
                .disabled(title.isEmpty)
            }
        }
    }
}
#Preview {
    let listVM = ListViewModel()
    let authVM = AuthViewModel()
    
    authVM.userID = "preview-user-id"
    authVM.nickname = "Preview User"
    authVM.isAuthenticated = true
    authVM.isNicknameSet = true
    
    let previewListItem = ListItem(
        id: "0",
        title: "Preview List",
        isCompleted: false,
        shareCode: "ABC123"
    )
    
    return NavigationStack {
        ListDetailView(listItem: .constant(previewListItem))
    }
    .environment(listVM)
    .environment(authVM)
}


