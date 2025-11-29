//
//  SharedListView.swift
//  SharedList
//
//  Created by 박지호 on 11/12/25.
//

import SwiftUI

struct SharedListView: View {
    @Environment(ListViewModel.self) private var listVM
    @Environment(AuthViewModel.self) private var authVM
    
    private let gradient = LinearGradient(
        colors: [Color.blue.opacity(0.25), Color.purple.opacity(0.35), Color.black.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    @State private var selectedListItems: [ListItem] = []
    
    @State private var isDeleteAlertPresented = false
    @State private var isNewListSheetPresented: Bool = false
    @State private var isJoinSheetPresented: Bool = false
    @State private var isSettingsSheetPresented: Bool = false
    @State var isEditMode: Bool = false
    @State var editingListItem: ListItem? = nil
    
    @State private var title: String = ""
    @State private var subtitle: String? = nil
    @State private var dueDate: Date? = nil
    
    // @Environment(\.dismiss) private var dismiss
    var body: some View {
        @Bindable var listVM = listVM
        
        NavigationStack {
            ZStack {
                gradient
                    .ignoresSafeArea()
                
                            if listVM.isLoading {
                                loadingView
                            } else if listVM.listItems.isEmpty {
                                emptyView
                            } else {
                    List {
                        Section {
                            header
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                        .listSectionSeparator(.hidden)
                        
                        Section {
                                    ForEach($listVM.listItems) { $item in
                                        listCard(for: $item)
                                    .listRowInsets(EdgeInsets(top: 9, leading: 20, bottom: 9, trailing: 20))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                            .onMove { source, destination in
                                if isEditMode {
                                    listVM.startReordering()
                                    listVM.listItems.move(fromOffsets: source, toOffset: destination)
                                    listVM.updateListOrder(userID: authVM.userID)
                                }
                            }
                        }
                        .listSectionSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, Binding(
                        get: { isEditMode ? .active : .inactive },
                        set: { newValue in
                            isEditMode = (newValue == .active)
                        }
                    ))
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isEditMode {
                        Button {
                            editingListItem = selectedListItems.first
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .disabled(selectedListItems.count != 1)
                        
                        Button {
                            isDeleteAlertPresented = true
                        } label: {
                            Label(String(localized: "delete_\(selectedListItems.count)"), systemImage: "trash")
                        }
                        .disabled(selectedListItems.isEmpty)
                    } else {
                        Button {
                            isSettingsSheetPresented = true
                        } label: {
                            Image(systemName: "person.crop.circle")
                                .font(.title3)
                        }
                    }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    
                    Button {
                        isEditMode.toggle()
                        if !isEditMode {
                            selectedListItems.removeAll()
                        }
                    } label: {
                        Image(systemName: isEditMode ? "checkmark.circle.fill" : "gear")
                            .foregroundStyle(isEditMode ? .green : .primary)
                    }
                    
                    if !isEditMode {
                    Menu {
                        Button {
                                isJoinSheetPresented = true
                        } label: {
                            Label(String(localized: "join_shared_list"), systemImage: "square.and.arrow.up")
                                .font(.headline)
                        }
                        Button {
                                isNewListSheetPresented = true
                        } label: {
                            Label(String(localized: "new_list"), systemImage: "plus")
                                .font(.headline)
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    }
                }
            }
            .sheet(isPresented: $isJoinSheetPresented) {
                addSharedListItemView(isJoinSheetPresented: $isJoinSheetPresented)
                    .environment(listVM)
                    .environment(authVM)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isNewListSheetPresented) {
                Add_EditListItemView(selectedListItems: $selectedListItems)
                    .environment(listVM)
                    .environment(authVM)
                    .presentationDetents([.fraction(0.7), .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isSettingsSheetPresented) {
                SettingsView()
                    .environment(authVM)
                    .environment(listVM)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingListItem) { selectedList in
                Add_EditListItemView(
                    selectedListItems: $selectedListItems,
                    editingListID: selectedList.id,
                    title: selectedList.title,
                    subtitle: selectedList.subtitle,
                    dueDate: selectedList.dueDate
                )
                .environment(listVM)
                .environment(authVM)
                .presentationDetents([.fraction(0.7), .large])
                .presentationDragIndicator(.visible)
            }
            .alert(String(localized: "delete_list_title"), isPresented: $isDeleteAlertPresented) {
                Button(String(localized: "cancel"), role: .cancel) { }
                Button(String(localized: "delete"), role: .destructive) {
                    Task {
                        let selectedIDs = selectedListItems.map { $0.id }
                        await listVM.leaveLists(listIDs: selectedIDs, userID: authVM.userID)
                        selectedListItems.removeAll()
                        isEditMode = false
                    }
                }
            } message: {
                Text("delete_list_message_\(selectedListItems.count)")
            }
            .task {
                // 실시간 리스너 시작 (userID가 있을 때만)
                if !authVM.userID.isEmpty {
                    listVM.observeLists(userID: authVM.userID)
                }
            }
            .onDisappear {
                // 화면을 벗어나면 리스너 정리 (메모리 누수 방지)
                listVM.stopObserving()
            }
            .alert(String(localized: "error"), isPresented: Binding(
                get: { listVM.errorMessage != nil },
                set: { value in
                    if !value { listVM.errorMessage = nil }
                }
            )) {
                Button(String(localized: "confirm"), role: .cancel) {}
            } message: {
                Text(listVM.errorMessage ?? String(localized: "unknown_error"))
            }
        }
    }
        
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("shared_list_title")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
            Text("shared_list_subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private var emptyView: some View {
        ContentUnavailableView(
            String(localized: "empty_list_title"),
            systemImage: "sparkles",
            description: Text("empty_list_description")
        )
        .foregroundStyle(.secondary)
    }
        
    // MARK: - listCard
    @ViewBuilder
    private func listCard(for item: Binding<ListItem>) -> some View {
        let value = item.wrappedValue
        
        let cardContent = HStack {
            if isEditMode {
                Button {
                    if let index = selectedListItems.firstIndex(where: { $0.id == value.id }) {
                        selectedListItems.remove(at: index)
                    } else {
                        selectedListItems.append(value)
                    }
                } label: {
                    Image(systemName: selectedListItems.contains(where: { $0.id == value.id }) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selectedListItems.contains(where: { $0.id == value.id }) ? .green : .secondary)
                        .frame(width: 32, height: 32)
                }
            }
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(value.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    let sharedCount = value.sharedUserIDs.filter { $0 != authVM.userID }.count
                    if sharedCount > 0 {
                        Label(String(localized: "shared_with_\(sharedCount)"), systemImage: "person.2.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let subtitle = value.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .center, spacing: 16) {
                    listVM.completionBadge(for: value)
                        Spacer()
                        if let dueText = listVM.dueDateText(for: value.dueDate) {
                            Label(dueText, systemImage: "calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(thinMartialRoundedRectangleModifier())
            
        }
        
        if isEditMode {
            cardContent
        } else {
            NavigationLink(destination: ListDetailView(listItem: item)) {
                cardContent
            }
        }
    }
}
// MARK: - Private StructView
struct addSharedListItemView : View {
    @Environment(ListViewModel.self) private var listVM
    @Environment(AuthViewModel.self) private var authVM
    @Binding var isJoinSheetPresented: Bool
    @State private var sharedCode: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("add_list_by_code")
                                .font(.headline)
                            TextField(String(localized: "enter_invite_code"), text: $sharedCode)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Button {
                    Task {
                        let success = await listVM.joinList(with: sharedCode, userID: authVM.userID)
                        if success {
                            isJoinSheetPresented = false
                        }
                    }
                } label: {
                    Text("confirm")
                        .foregroundStyle(Color.white)
                        .padding(.vertical)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
                .disabled(sharedCode.isEmpty)
            }
        }
        .navigationTitle(String(localized: "join_list"))
    }
}
struct Add_EditListItemView : View {
    @Environment(ListViewModel.self) private var listVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @Binding private var selectedListItems: [ListItem]

    /// 수정할 리스트 ID (nil이면 새로 생성)
    let editingListID: String?
    
    @State private var title: String
    @State private var subtitle: String?
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool
    
    /// 수정 모드인지 여부
    private var isEditMode: Bool { editingListID != nil }
    
    init(
        selectedListItems: Binding<[ListItem]>,
        editingListID: String? = nil,
        title: String = "",
        subtitle: String? = nil,
        dueDate: Date? = nil
    ) {
        self.editingListID = editingListID
        _selectedListItems = selectedListItems
        _title = State(initialValue: title)
        _subtitle = State(initialValue: subtitle)
        _dueDate = State(initialValue: dueDate)
        _hasDueDate = State(initialValue: dueDate != nil)
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
                                get: { subtitle ?? "" },
                                set: { subtitle = $0.isEmpty ? nil : $0 }
                            ))
                        }
                    }
                    
                    Section {
                        Toggle(String(localized: "set_due_date"), isOn: Binding(
                            get: { hasDueDate },
                            set: { newValue in
                                hasDueDate = newValue
                                if newValue {
                                    if dueDate == nil {
                                        dueDate = Date()
                                    }
                                } else {
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
                        if let listID = editingListID {
                            // 수정 모드
                            await listVM.updateList(
                                listID: listID,
                                title: title,
                                subtitle: subtitle,
                                dueDate: dueDate
                            )
                        } else {
                            // 생성 모드
                            await listVM.createList(
                                title: title,
                                subtitle: subtitle,
                                dueDate: dueDate,
                                userID: authVM.userID
                            )
                        }
                        selectedListItems.removeAll()
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
            .navigationTitle(isEditMode ? String(localized: "edit_list") : String(localized: "new_list"))
            .navigationBarTitleDisplayMode(.inline)
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
    
    return NavigationStack {
        SharedListView()
    }
    .environment(listVM)
    .environment(authVM)
}
