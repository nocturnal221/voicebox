# VoiceBox 📣

A Flutter mobile application that enables students to anonymously submit complaints,
suggestions, and feedback to administrators — ensuring every voice is heard without
fear of identification.

## Problem It Solves

In institutional environments (schools, universities, hostels), students often hesitate
to raise concerns due to fear of identification or retaliation. VoiceBox solves this by
providing a fully anonymous submission system with a secure role-based access structure,
so students speak freely and admins respond effectively.

## Features

### Authentication

- Email & password registration with Supabase Auth
- Email verification before login is allowed
- Role-based login — users and admins use the same login screen with a toggle
- Secure role mismatch detection — an admin account cannot log in as a user and vice versa
- Proper session management with `signOut()` on logout

### User Side

- Submit complaints, suggestions, and feedback
- Choose from 6 categories: Infrastructure, Academic, Hostel, Canteen, Management, Other
- All submissions are fully anonymous — no user identity is stored with submissions
- Form validation with friendly error messages
- Loading state feedback during submission

### Admin Side

- View all submissions in real-time
- Filter submissions by type (All, Complaint, Suggestion, Feedback)
- Summary stat cards showing total, complaint, and suggestion counts
- Pull-to-refresh to fetch latest submissions
- Submissions sorted by newest first

## Tech Stack

| Layer          | Technology          |
| -------------- | ------------------- |
| Frontend       | Flutter (Dart)      |
| Backend        | Supabase            |
| Authentication | Supabase Auth       |
| Database       | Supabase PostgreSQL |

## Database Schema

**Table: `submissions`**
| Column | Type | Description |
|---|---|---|
| `id` | bigint | Auto-generated primary key |
| `created_at` | timestamptz | Auto-set on insert |
| `submission_type` | text | Complaint / Suggestion / Feedback |
| `category` | text | Infrastructure / Academic / Hostel etc. |
| `title` | text | Brief title of the submission |
| `description` | text | Detailed description |

> Note: No `user_id` column — anonymity is guaranteed by design.

## Project Structure

lib/
├── main.dart
├── screens/
│ ├── login_screen.dart
│ ├── register_screen.dart
│ ├── user_home_screen.dart
│ └── admin_home_screen.dart

## Getting Started

1. **Clone the repository**

```bash
git clone https://github.com/nocturnal221/voicebox.git
cd voicebox
```

2. **Install dependencies**

```bash
flutter pub get
```

3. **Configure Supabase**

In `main.dart`, replace with your own Supabase credentials:

```dart
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);
```

4. **Run the app**

```bash
flutter run
```

## Known Limitations

- Email verification redirect not yet configured for mobile deep links
- Row Level Security (RLS) on the submissions table is pending setup
- Admin dashboard does not auto-refresh in real-time (manual refresh required)

## Future Improvements

- Real-time submission updates using Supabase Realtime
- Admin ability to mark submissions as reviewed or resolved
- Push notifications for new submissions
- RLS policies for secure data access
- Deep link configuration for email verification on mobile

## Author

**nocturnal221** — [GitHub Profile](https://github.com/nocturnal221)

---

> Built with Flutter 💙 and Supabase ⚡
