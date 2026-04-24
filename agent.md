# AGENTS — Project Technology Choices

This file defines the technical direction for the **episign** attendance-signing project.
It is the reference for implementation decisions and overrides the subject document where they conflict.

---

## Core Product Direction

- Build a native iOS app for attendance signing, paired with a web page for teachers.
- Replace the QR-code presence proof used by Edusign with **ultrasonic in-room validation**: the teacher's browser emits a TOTP over ultrasound (17–20 kHz, inaudible), the student's iPhone listens and decodes it.
- Keep the system minimal, reliable, and demo-ready within the 3-day project timeframe.

## Major Corrections vs Subject

- The subject leaves the backend open ("Supabase or equivalent ready-made"). We **commit to Supabase** and reject the Go/Postgres-from-scratch variant: the time saved is invested in iOS polish, ultrasound reliability, and pitch quality.
- The subject mentions QR code as the baseline. Our product angle is **ultrasound instead of QR**, with manual TOTP entry as a universal fallback.
- The teacher side is a **web page**, not an iOS app: it runs on any classroom laptop, removes hardware dependency, and keeps the simulator-demo path open for teams without iPhones.

---

## High-Level Architecture

```
┌─────────────────────┐              ┌─────────────────────┐
│   Teacher web page  │              │   Student iOS app   │
│   (HTML+JS+WASM)    │              │   (SwiftUI)         │
│                     │              │                     │
│ - Auth (teacher)    │              │ - Supabase Auth     │
│ - Fetches session   │              │ - Lists sessions    │
│   secret via        │              │ - Mic capture       │
│   Edge Function     │              │ - ggwave decode     │
│ - Generates TOTP    │              │ - Spectrum viz      │
│ - Emits via         │    ultrasound│ - PencilKit sig     │
│   ggwave-wasm       │ ─────────────▶ - Calls sign EF    │
└──────────┬──────────┘              └──────────┬──────────┘
           │                                    │
           │      ┌──────────────────┐          │
           │      │    Supabase      │          │
           └──────▶                  ◀──────────┘
                  │ • Auth (JWT)     │
                  │ • Postgres + RLS │
                  │ • Storage (PNG)  │
                  │ • Edge Functions │
                  │   - sign         │
                  │   - teacher-key  │
                  └──────────────────┘
```

- **Teacher web page**: generates the current session TOTP, emits it continuously via ggwave-wasm in the 17–20 kHz band. Also displays the TOTP in large type as a manual fallback.
- **Student iOS app**: listens for the ultrasound signal, decodes the 6-digit TOTP via ggwave, lets the student sign, submits to the backend.
- **Supabase**: auth, data, storage, and all server-side validation logic. Source of truth.

---

## iOS Stack and UX

- **Language/UI**: Swift 5.9+, SwiftUI, iOS 17+ target, Xcode 15+.
- **Persistence**: SwiftData for cached sessions, user profile, device_id, and offline signature drafts.
- **Signature capture**: PencilKit via `UIViewRepresentable`. Apple Pencil support (pressure + tilt).
- **Audio pipeline**: `AVAudioEngine` with a single input tap at hardware sample rate (48 kHz typical). One tap, two consumers via fan-out:
  - **Decoder consumer**: feeds buffers to a `GGWave` actor that decodes ultrasonic payloads and publishes detected TOTPs on an `AsyncStream<String>`.
  - **Visualizer consumer**: `vDSP_DFT` over the same buffers, 64-bar spectrum restricted to the 17–21 kHz band, displayed in a SwiftUI `Canvas`.
- **Secret storage**: JWT token in Keychain. Device ID (UUID) generated on first launch, persisted in SwiftData.
- **Visual direction**: clean, modern SwiftUI look (iOS 18 style). Main signing screen features an animated spectrum / soundwave visualization as presence-feedback element. Two primary tabs via `TabView`:
  - **Sign**: current-day sessions and active signing flow.
  - **History**: past signatures and upcoming classes.
- **Onboarding / Login / Settings**: handled as modal or stack-pushed views, not as a tab. Settings exposes device binding info, logout, and RGPD notice.

---

## Ultrasound Protocol

- **Library**: [ggwave](https://github.com/ggerganov/ggwave) on both sides. Do not roll our own FSK encoder.
  - iOS: C sources compiled as a local SwiftPM target, exposed through a thin Swift wrapper actor.
  - Web: ggwave-wasm via the prebuilt emscripten build from the repo.
- **Band**: ultrasonic presets (17–20 kHz). Audible-range presets are forbidden — the signal must remain inaudible to humans present in the room.
- **Payload**: the current 6-digit TOTP as ASCII. The app validates format (`^\d{6}$`) before forwarding to the backend.
- **Emission mode**: continuous loop on the teacher page. Multiple students can decode the same broadcast in parallel — the uniqueness constraint is enforced server-side by `(student_id, course_id, slot)`, not by gating emission.

---

## Presence Validation Model

A signature is accepted only when **all** of the following hold:

1. The student is authenticated (valid Supabase JWT).
2. The session exists and the current time is within its `[starts_at, ends_at]` window.
3. The submitted TOTP validates against the teacher's secret, within a one-step window (±30 s).
4. No signature already exists for this `(student_id, course_id, slot)` triplet.
5. The `device_id` matches the one bound to the student account.
6. (Optional) Geolocation is within the configured geofence of the classroom.

All these checks run inside the `sign` Edge Function with the `service_role_key`. The iOS app never judges TOTP validity itself — it forwards and reports the result.

The ultrasound channel is a **usability and social-friction** feature: it auto-fills the TOTP so the student does not have to read a display. It is also a **physical-presence signal** because the sound does not cross walls. It is **not** the server's validation mechanism — the server validates the TOTP, regardless of how the student obtained it.

---

## Backend: Supabase

- **Auth**: email magic link via `supabase.auth.signInWithOtp({ email })`. JWT returned, stored in iOS Keychain.
- **Database**: Supabase-managed Postgres. Schema in SQL migration files committed to the repo.
- **Storage**: one bucket `signatures` for the PNG files, with RLS allowing only the owning student to read their own signatures.
- **Edge Functions** (Deno/TypeScript):
  - `sign`: the core validation and insertion function (see flow above).
  - `teacher-session-key`: authenticated endpoint returning the TOTP secret for a given session to the teacher page (teacher auth only).
- **Secrets**: Edge Functions access the database with the `service_role_key`, never exposed to clients. The TOTP generation library used is `otpauth` (Deno-compatible via esm.sh).

---

## API Shape

**PostgREST (direct DB access, JWT-authenticated, RLS-protected)**:

- `GET /rest/v1/courses` — student's sessions.
- `GET /rest/v1/signatures?student_id=eq.<uuid>` — history.

**Edge Functions**:

- `POST /functions/v1/sign` — submit a signature. Body: `{ session_id, totp, signature_png_base64, slot, device_id, timestamp, latitude?, longitude?, sha256 }`. Returns `{ ok: true, signature_id }` or typed error (`invalid_totp`, `out_of_window`, `already_signed`, `device_mismatch`, `unauthorized`).
- `POST /functions/v1/teacher-session-key` — teacher retrieves TOTP secret for a session.

**Supabase Auth SDK**: `signInWithOtp`, `signOut`, session refresh.

---

## Data Model

```
students (id UUID PK = auth.uid(), email TEXT, name TEXT, device_id TEXT)
teachers (id UUID PK, name TEXT, totp_secret TEXT)  -- totp_secret never exposed client-side
courses  (id UUID PK, title TEXT, date DATE, slot TEXT, room TEXT,
          teacher_id UUID FK, starts_at TIMESTAMPTZ, ends_at TIMESTAMPTZ)
signatures (id UUID PK, student_id UUID FK, course_id UUID FK, slot TEXT,
            image_path TEXT, timestamp TIMESTAMPTZ, device_id TEXT,
            latitude DOUBLE PRECISION NULL, longitude DOUBLE PRECISION NULL,
            sha256 TEXT, invalidated_at TIMESTAMPTZ NULL, invalidation_reason TEXT NULL,
            UNIQUE(student_id, course_id, slot))
```

**RLS policies**:

- `students`: SELECT/UPDATE where `id = auth.uid()`.
- `courses`: SELECT open to any authenticated student.
- `signatures`: SELECT where `student_id = auth.uid()`. No client INSERT/UPDATE — writes only through the `sign` Edge Function.
- `teachers`: no policy for authenticated role. Accessible only via `service_role_key`.

---

## Security Baseline

- Server-side TOTP validation, always. The client never judges.
- TOTP secret stored only in `teachers.totp_secret`, read only in Edge Functions with `service_role_key`.
- JWT in iOS Keychain (not `UserDefaults`, not SwiftData).
- Device binding enforced in the `sign` Edge Function.
- Rate limiting on `sign` (Supabase Edge Functions support per-IP and per-user limits).
- SHA-256 integrity hash stored alongside each signature.
- Info.plist permission strings in French, clearly justified:
  - `NSMicrophoneUsageDescription`: explains the inaudible-code mechanism.
  - `NSLocationWhenInUseUsageDescription`: explains the optional geofence.
- No third-party analytics. No console logging of TOTPs in release builds.

---

## Offline Behavior

- Sessions list is cached in SwiftData; the UI shows stale data with an indicator if offline.
- A signature created offline is persisted as `LocalSignatureDraft` and retried when connectivity returns (up to the session's `ends_at` window — after that, it is dropped with user notification).
- This mode is mandatory: the Wi-Fi at the pitch venue is not a hypothesis we want to rely on.

---

## Native iOS Features (for the "2 iOS-only APIs" criterion)

Primary (must ship):

- **PencilKit signature capture** with pressure and tilt.
- **AVAudioEngine + vDSP ultrasound decoding and spectrum visualization**.

Secondary (pick at least one):

- **WidgetKit**: home-screen widget showing today's next unsigned session.
- **ActivityKit**: Live Activity showing "Session X — signed at HH:MM" for a few minutes after signing.
- **App Intents**: Siri shortcut "Sign my session".
- **CoreLocation geofencing**: optional geofence check during signing.

The widget is the safest pick in terms of visibility during pitch.

---

## Delivery Priorities

1. **Day 1 MVP**: end-to-end sign flow with **manual** TOTP entry (no ultrasound yet). Supabase schema, RLS, seed data, auth, sessions list, PencilKit, `sign` Edge Function, history.
2. **Day 2**: ggwave integration on both sides, spectrum visualizer, at least one secondary native feature, offline draft retry.
3. **Day 3**: polish, device binding hardening, error states, pitch slides, live demo rehearsal.

Manual fallback is never dropped: the ultrasound is additive, not replacive.

---

## Out of Scope for the 3-Day MVP

- Admin web dashboard (Supabase dashboard is used for the pitch).
- PDF export of attendance sheets.
- Teacher iOS app (the web page is sufficient and more robust).
- Multi-tenant / multi-school architecture.
- Email notifications / push notifications.
- Biometric auth (Face ID) on app open — post-MVP.
