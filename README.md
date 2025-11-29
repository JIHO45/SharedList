# SharedList

<p align="center">
  <img src="SharedList/Assets.xcassets/AppIcon.appiconset/SharedListAppIcon.png" width="120" height="120" alt="SharedList Icon"/>
</p>

<p align="center">
  <strong>Lists feel lighter when everyone stays in sync.</strong><br/>
  <em>A real-time collaborative list app built with SwiftUI, Firebase, and MVVM.</em>
</p>

<p align="center">
  <a href="#about">About</a> •
  <a href="#features">Features</a> •
  <a href="#tech-stack">Tech Stack</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#screenshots">Screenshots</a> •
  <a href="#installation">Installation</a> •
  <a href="#roadmap">Roadmap</a>
</p>

---

<a id="about"></a>

## 📱 About

SharedList helps friends, partners, and teams stay perfectly aligned on shared tasks. Invite others with a simple code, collaborate in real time, and keep personal ordering so every list feels tailored to you. The app emphasizes clean SwiftUI design, modern async/await flows, and a fully localized experience (English & Korean) ready for the App Store.

---

## 👤 Role & Responsibilities

- Led the end-to-end SwiftUI build, including custom navigation chrome and toolbar integrations compatible with iOS 17+.
- Architected the MVVM layer and Firebase services, covering authentication, Firestore syncing, and invite-code workflows.
- Drove 100% English/Korean localization by consolidating `Localizable.xcstrings` and refactoring all user-facing strings.
- Removed deprecated Deep Link stack, simplified app entry, and documented release readiness for portfolio review.

---

## 📊 Impact & Outcomes

- Eliminated the gray navigation bar artifact on physical devices by reverting to a custom SwiftUI header while keeping the native toolbar for actions.
- Consolidated 60+ stray localization keys, bringing `Localizable.xcstrings` to 100% English coverage and zero stale warnings.
- Simplified onboarding by deleting unused deep-link code paths and routing users directly into `SharedListView`.
- Validated the UI on both simulator and real hardware to ensure gradients, toolbar behavior, and list styling match the design intent.

---

<a id="features"></a>

## ✨ Features

### Core Features
- 🎯 **Collaborative Lists** – Create, edit, and delete shared lists with instant syncing
- ✅ **Task Management** – Add items, toggle completion, and reorder with smooth drag & drop
- 🔗 **Invite Codes** – Share a unique code so others can jump into your list securely
- 🧑‍🤝‍🧑 **Personal Ordering** – Each user keeps their own preferred ordering without affecting collaborators
- 🌍 **Localization** – Every screen supports English and Korean with `Localizable.xcstrings`

### Technical Features
- 🔐 **Sign in with Apple** – Authentication powered by Firebase Auth
- ☁️ **Real-time Firestore Sync** – `addSnapshotListener` drives instant updates across devices
- 🧠 **MVVM + Services** – Views stay declarative while ViewModels orchestrate Firebase services
- ⚡️ **Async/Await Everywhere** – Structured concurrency for predictable data flow
- 🎨 **Custom Navigation Treatments** – Transparent navigation styling in SwiftUI with custom bars

---

<a id="tech-stack"></a>

## 🛠 Tech Stack

| Category | Technology |
|----------|------------|
| UI Framework | SwiftUI |
| Backend | Firebase Firestore |
| Authentication | Firebase Auth (Sign in with Apple) |
| Architecture | MVVM + Service layer |
| Concurrency | Swift Async/Await |
| Localization | `Localizable.xcstrings` (EN, KO) |
| Build Tools | Swift Package Manager, Xcode 15 |

---

<a id="architecture"></a>

## 🏗 Architecture

```
SharedList/
├── App/
│   └── SharedListApp.swift               # Entry point & Firebase bootstrap
├── Models/
│   ├── ListItem.swift                    # Codable, Identifiable data structures
│   └── TodoItem.swift
├── ViewModels/
│   ├── ListViewModel.swift               # Real-time sync, ordering, mutations
│   └── AuthViewModel.swift               # Sign in with Apple, session state
├── Views/
│   ├── SharedListView.swift              # Home with active lists & invites
│   ├── ListDetailView.swift              # Custom nav bar + toolbar actions
│   ├── LoginView.swift                   # Marketing + Sign in with Apple
│   ├── NicknameSetupView.swift           # First-run onboarding
│   ├── EditNicknameView.swift
│   └── SettingsView.swift                # Account + support email
└── Services/
    ├── AuthService.swift                 # Firebase Auth wrapper
    └── FirestoreService.swift            # List CRUD + invite code helpers
```

- **Models** – Pure data definitions conforming to `Codable`, `Identifiable`
- **ViewModels** – `@MainActor @Observable` classes managing business logic and Firebase calls
- **Views** – SwiftUI-only rendering with localized strings and no side effects
- **Services** – Testable Firebase access layer (Auth, Firestore, invite utilities)

---

<a id="key-implementation-details"></a>

## 🔑 Key Implementation Details

### Real-time Firestore Sync
`ListViewModel` consumes `AsyncStream<[ListItem]>` sourced from Firestore `addSnapshotListener`, ensuring every participant sees updates in milliseconds without manual refresh.

### Share Codes & Membership
Each list owns a short invite code stored in Firestore. When a user enters a code, the ViewModel validates ownership, attaches the user’s UID, and triggers a permissions refresh—no manual linking required.

### Personal Ordering
User-specific ordering lives in `UserDefaults`, keyed by list ID. The Firestore payload remains canonical, while local ordering re-applies after every snapshot to keep UX personalized.

### Localization Pipeline
All user-facing strings go through `Localizable.xcstrings` with full English/Korean coverage. ViewModels rely on `String(localized:)` for errors so alerts stay translated too.

### Swift Concurrency
Firebase reads/writes are exposed as async functions. ViewModels `await` service calls, update `@Published` state on the main actor, and surface friendly errors for the UI.

---

<a id="screenshots"></a>

## 📸 Screenshots

Capture set (home, detail, onboarding) is being finalized for App Store Connect; placeholders will be replaced once the marketing build is shot.

---

<a id="installation"></a>

## 🚀 Installation

**Requirements**
- Xcode 15.0+
- iOS 17.0+ target
- Firebase project with Firestore & Authentication enabled

**Setup**
```bash
git clone https://github.com/JIHO45/SharedList.git
cd SharedList
open SharedList.xcodeproj
```
1. Add your `GoogleService-Info.plist` to the `SharedList` target.
2. Configure Sign in with Apple & Firestore rules in the Firebase Console.
3. Build and run on a simulator or physical device.

---

<a id="roadmap"></a>

## 🗺 Roadmap

| Phase | Focus | Target | Status |
|-------|-------|--------|--------|
| 1.0 | Core collaboration, localization, toolbar polish | Oct 2025 | ✅ Shipped |
| 1.1 | Widget & Live Activity previews | Jan 2026 | 🟡 In research |
| 1.2 | Push notifications for invites & edits | Mar 2026 | 🔜 Planned |
| 1.3 | App Store launch (screenshots, metadata, TestFlight) | Apr 2026 | 🔜 Planned |

---

<a id="documentation"></a>

## 📁 Documentation

Documentation summaries ship with the repo so reviewers can trace decisions:

- `Docs/LOCALIZATION_GUIDE.md` *(planned)* – Adding new strings & languages
- `Docs/FIREBASE_SETUP.md` *(planned)* – Project configuration, security rules
- `Docs/TEST_PLAN.md` *(planned)* – Manual QA checklist before release

---

<a id="author"></a>

## 👤 Author

**JIHO45**
- GitHub: [@JIHO45](https://github.com/JIHO45)
- Email: pjh030331@gmail.com

---

<a id="privacy-policy"></a>

## 🔐 Privacy Policy

- **Data Collected**: Name, email (only when using Sign in with Apple)
- **Purpose**: Authentication and syncing personalized list data
- **Storage**: Securely stored in iCloud Keychain and UserDefaults
- **Third-party Sharing**: None
- **Contact**: pjh030331@gmail.com

---

<a id="support"></a>

## 🆘 Support

- **Support Email**: pjh030331@gmail.com

---

<a id="license"></a>

## 📄 License

SharedList is available for portfolio and educational use. All rights reserved.
