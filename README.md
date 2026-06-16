# Zelv Track

A clean, local-first **dopamine & routine tracker** built with Flutter. Designed for people who want to build strong daily habits, track projects with subtasks, and manage a smart shopping list — all offline, all private.

---

## What it does

### Routine Tracker
- Day split into fixed **time blocks**: Morning, Lab/Work, Midday, Afternoon, Evening, Night
- Each block has habits you check off throughout the day
- **Good Morning card** at the top shows today's progress, streak, and date
- Habits marked as non-negotiable are highlighted differently

### Stats & Heatmap
- **7-day bar chart** showing daily completion %
- **Habit heatmap** — color-coded by time block so you see patterns at a glance
- **Habit rates** — ranked list of your most/least consistent habits
- Streak counter and 7-day average

### Projects (3-level hierarchy)
```
Project
  └── Task Group  (e.g. Research, Build, Ship)
        └── Subtask  (individual actionable item)
```
- Collapsible task groups with progress bars
- Archive completed projects
- Add / delete projects, groups, and subtasks inline

### Shopping List
- Items organized by **shop** (customizable — add any store with an emoji)
- Optional **brand** field per item
- Tap to check off, long-press to delete
- "In cart" done section at the bottom
- Manage shops inline

---

## Design

- Inspired by the **Zelv** app aesthetic — clean cards, colored left stripes, pastel stat chips
- **Light & dark theme** with multiple accent color presets
- Block-specific colors: amber = morning, sky = lab, green = midday, violet = afternoon, orange = evening, indigo = night
- Fully local via **Hive** — no account, no internet, no tracking

---

## Tech stack

| Layer | Tech |
|-------|------|
| Framework | Flutter 3.x (Dart) |
| Storage | Hive (local NoSQL) |
| State | setState + service singleton |
| Platforms | Android, Linux desktop |

---

## Getting started

```bash
git clone https://github.com/itsgurmailsingh-png/zelv-track.git
cd zelv-track
flutter pub get

# Run on Linux desktop
flutter run -d linux

# Build Android APK
flutter build apk --release
```

Requires Flutter 3.x. Android SDK needed for APK builds.

---

## Customising habits

Edit `lib/models/models.dart` → `defaultHabits()`. Each habit needs:

| Field | Description |
|-------|-------------|
| `id` | Unique string |
| `label` | Display text |
| `blockId` | `morning` / `lab` / `midday` / `afternoon` / `evening` / `night` |
| `isNonNeg` | `true` = non-negotiable anchor (highlighted in amber) |

Data is seeded once on first launch. To force a re-seed, bump `_kProjectSchema` in `storage_service.dart`.

---

## License

MIT
