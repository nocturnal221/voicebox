<div align="center">

<img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter" />
<img src="https://img.shields.io/badge/Supabase-Backend-green?logo=supabase" />
<img src="https://img.shields.io/badge/Platform-Android%20%7C%20Windows-lightgrey" />
<img src="https://img.shields.io/badge/License-MIT-yellow" />

# 📣 VoiceBox

### Anonymous Complaint & Suggestion Platform

**VoiceBox** is a Flutter + Supabase application that lets students and university members submit complaints, suggestions, and feedback **anonymously** — while giving DSW admins and category sub-admins full tools to manage, respond, and resolve them efficiently.

</div>

---

## ✨ Features Overview

### 👤 General User
- **Anonymous submissions** — identity never stored; tracked only by device token
- Submit **Complaints**, **Suggestions**, or **Feedback**
- Choose from categories: `Infrastructure`, `Academic`, `Hostel`, `Canteen`, `Management`, `Other`
- Set **priority** (High / Medium / Low) and attach an optional link
- **Duplicate detection** — warns if a similar title was submitted in the last 14 days
- **Spam filter** — blocked words list prevents abusive language
- **Auto-routing** — submissions automatically assigned to the correct sub-admin based on category
- View **My Submissions** with search, filter by status, and sort by newest / oldest / priority / needs attention
- **Due date tracking** — each submission has a 3-day SLA; overdue items are flagged
- **Submission chat** — send follow-up messages directly to the admin team
- **Satisfaction feedback** — after resolution, mark as Satisfied or Not Satisfied
- **Reopen request** — if not satisfied, trigger a reopen automatically
- **In-app notifications** — receive updates when status changes or admin replies
- **CSV export** — copy current filtered list to clipboard as CSV
- **Dark mode toggle** — switch theme anytime from the app bar
- **Notification badge** — unread count shown on the bell icon

### 🛡️ Main Admin (DSW)
- See **all submissions** across all categories
- **DSW Dashboard** with scrollable stat cards: Total, Pending, In Progress, Solved, Unsatisfied
- Advanced **search** by title, description, category, status, or priority
- **Filter chips** by submission type and status
- **Sort** by Newest, Oldest, Priority, or Needs Attention
- **Overdue** and **reopen requested** summary chips in the header
- **Analytics screen** with:
  - Status split (Pending / In Progress / Solved)
  - Category breakdown bar chart
  - Submission types breakdown
  - Priority mix visualization
  - Copy summary to clipboard
- **Assign / reassign** submissions to sub-admins
- Update submission **status** (Pending → In Progress → Solved)
- Set or update **priority** per submission
- Set **due date** for each submission
- Write a **progress note** visible to the user
- Reply in **submission chat**
- View **user satisfaction** and **reopen requests**
- **CSV export** of the current filtered queue
- **Audit log** — all admin actions recorded to `audit_logs` table

### 🗂️ Sub-Admin (Category Admin)
- Dashboard scoped **only** to their assigned category
- Same stat cards: Total, Pending, In Progress, Solved, Unsatisfied
- Search, filter, and sort within their category
- Overdue and reopen-requested summary badges
- Update **status**, **priority**, **progress note**, and **due date**
- Reply in **submission chat**
- **CSV export** of their category queue
- Cannot assign to other sub-admins (main admin only)

---

## 🗃️ Database Schema (Supabase)

### `profiles`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid (PK) | References `auth.users` |
| `full_name` | text | User's display name |
| `role` | text | `user`, `sub_admin`, `main_admin` |
| `assigned_category` | text | Sub-admin's category (nullable) |

### `submissions`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid (PK) | Auto-generated |
| `submission_type` | text | Complaint / Suggestion / Feedback |
| `category` | text | Infrastructure / Academic / etc. |
| `title` | text | Short summary |
| `description` | text | Full details |
| `attachment_url` | text | Optional link |
| `device_token` | text | Anonymous identifier |
| `user_id` | uuid | Nullable (if logged in) |
| `assigned_to` | uuid | Sub-admin user ID |
| `status` | text | `pending`, `in_progress`, `solved` |
| `priority` | text | `high`, `medium`, `low` |
| `due_at` | timestamptz | SLA deadline |
| `progress_note` | text | Visible admin note |
| `satisfaction` | text | `satisfied`, `not_satisfied` |
| `satisfaction_comment` | text | User's feedback comment |
| `reopen_requested` | boolean | User requested reopen |

### `submission_messages`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid (PK) | Auto-generated |
| `submission_id` | uuid | FK → submissions |
| `sender_role` | text | `user` or `admin` |
| `sender_user_id` | uuid | Nullable |
| `device_token` | text | For anonymous user identification |
| `body` | text | Message content |
| `created_at` | timestamptz | Timestamp |

### `notifications`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid (PK) | Auto-generated |
| `device_token` | text | Recipient identifier |
| `title` | text | Notification title |
| `message` | text | Body text |
| `is_read` | boolean | Read status |
| `created_at` | timestamptz | Timestamp |

### `audit_logs`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid (PK) | Auto-generated |
| `submission_id` | uuid | FK → submissions |
| `actor_user_id` | uuid | Who performed the action |
| `action` | text | Action label |
| `details` | text | Description |
| `created_at` | timestamptz | Timestamp |

---

## 🏗️ Project Structure

```
lib/
├── main.dart                          # App entry point, AuthGate, routing
├── app_theme.dart                     # ThemeData, light/dark mode
├── app_settings.dart                  # Global theme mode notifier
├── app_widgets.dart                   # Shared reusable widgets
├── splash_screen.dart                 # Splash / onboarding screen
├── login_screen.dart                  # Login with user/admin toggle
├── register_screen.dart               # Registration with role selection
├── user_home_screen.dart              # User submission form
├── my_submissions_screen.dart         # User's submission list & filters
├── user_submission_detail_screen.dart # Detail, chat, feedback, reopen
├── notifications_screen.dart          # In-app notifications
├── admin_home_screen.dart             # DSW/Main admin dashboard
├── admin_submission_detail_screen.dart# Admin detail, actions, chat
├── admin_analytics_screen.dart        # Analytics & charts
└── sub_admin_home_screen.dart         # Category sub-admin dashboard
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.x
- Dart 3.x
- A Supabase project

### 1. Clone the repository
```bash
git clone https://github.com/yourusername/voicebox.git
cd voicebox
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Configure Supabase

Open `lib/main.dart` and replace with your own project credentials:

```dart
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);
```

### 4. Set up the database

Run the SQL setup in your Supabase **SQL Editor** to create all required tables, RLS policies, and helper functions. Contact the project maintainer for the full SQL setup file.

### 5. Run the app
```bash
flutter run
```

---

## 🔐 Authentication & Role System

| Role | Access | How to assign |
|---|---|---|
| `user` | Submit & track own submissions | Automatic on registration |
| `sub_admin` | Manage assigned category queue | Set manually in Supabase `profiles` table |
| `main_admin` | Full dashboard, analytics, all categories | Set manually in Supabase `profiles` table |

**Admins are never self-appointed.** Only someone with direct Supabase access can elevate a user to admin.

To promote a user:
```sql
UPDATE profiles
SET role = 'main_admin'   -- or 'sub_admin'
WHERE id = 'user-uuid-here';

-- For sub-admin, also set the category:
UPDATE profiles
SET role = 'sub_admin', assigned_category = 'Hostel'
WHERE id = 'user-uuid-here';
```

---

## 📦 Key Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.x.x
  shared_preferences: ^2.x.x
  uuid: ^4.x.x
```

---

## 📱 Build APK (Release)

To build a release APK for distribution:

```bash
flutter build apk --release
```

Output location:
```
build/app/outputs/flutter-apk/app-release.apk
```

Share the APK via Google Drive, GitHub Releases, or any file sharing service. The app requires an active internet connection to communicate with Supabase.

---

## 👥 Team

Built as a course project at **RUET (Rajshahi University of Engineering & Technology)**, Department of Computer Science & Engineering.

| | |
|---|---|
| **GitHub** | [@nocturnal221](https://github.com/nocturnal221) |

---

## 📄 License

This project is licensed under the MIT License.
