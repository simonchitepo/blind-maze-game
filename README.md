
### 1. The Core Engine (Dart/Flutter)

- **Maze Generator:** A custom algorithm that represents the labyrinth as a matrix of booleans. It ensures every generated maze is solvable using a depth-first search (DFS) validation.
- **State Management:** Utilizes a reactive approach to track "revealed" coordinates as the player moves.
- **Rendering:** Powered by Flutter's `CustomPainter`. This allows for high-performance rendering of "paint splatters" and "sonar pings" without the overhead of a heavy 3D engine like Unity.

### 2. Backend Infrastructure (Firebase)

- **Firestore:** Real-time sync for the global leaderboard.
- **Auth (Optional):** Anonymous authentication to track unique user progress.
- **Analytics:** Tracking level completion times to balance the difficulty curve across the 500 levels.

---
### UI mock ups 
![ui 1](<Screenshot 2026-04-06 211626.png>)
![ui 2](<Screenshot 2026-04-06 211730.png>)
![ui 3](<Screenshot 2026-04-06 211712.png>)
## 💡 Problem & Solution (Case Study)

### The Problem

Traditional maze games often become repetitive or too easy once the exit is visible. There is no "cognitive load" other than pathfinding. Players quickly memorize patterns and lose interest.

### The Solution: Blind Maze

By hiding the walls, we transform a pathfinding task into a **memory and spatial awareness challenge**.

- **Visual Feedback:** Instead of static walls, we use "Paint Splatters" (visual reward) and "Sonar Pings" (strategic resource) to give the player temporary breadcrumbs.
- **Scaling Difficulty:** Procedural generation allows us to scale the grid size from **5×5** (Tutorial) to **50×50** (Expert), keeping the challenge fresh.

---

## 🎮 Gameplay Mechanics

### Core Concept
Navigate from **START** to **EXIT** in a completely invisible maze. Walls are only revealed when you touch them, leaving a paint splatter as a memory marker.

### The Arsenal

| Power-Up | Icon | Effect | Max Charges |
|----------|------|--------|-------------|
| **Flashlight** | 🔦 | Directional cone reveal (120° radius) | 3 |
| **Paintball** | 🟢 | Large radius splash reveal (42px) | 6 |
| **Sonar Ping** | 📡 | Full-screen momentary reveal (3s) | 2 |
| **Ghost Mode** | 👻 | Temporary wall phasing (10s) | 1 (per level) |

### Level Progression
- **Total Levels:** 500 procedurally generated stages
- **Difficulty Scaling:** Increases every 50 levels
- **Tries per Level:** 100 attempts maximum
- **Score System:** Points based on unique cells explored per life

---

## 🚀 Installation & Requirements

### System Requirements

| Platform | Minimum Version | Architecture |
|----------|----------------|--------------|
| **Windows** | 10 / 11 | x64, ARM64 |
| **Android** | 5.0+ (API 21) | ARM64, x86_64 |
| **iOS** | 12+ | ARM64 |
| **macOS** | 10.15+ | x64, ARM64 |
| **Linux** | Ubuntu 18.04+ | x64 |

### Storage Requirements
- **Install Size:** ~150 MB
- **Cache Size:** ~50 MB (leaderboard & settings)
## 📊 Beta Performance Metrics (Case Study)

During our initial beta launch on the Microsoft Store, we tracked user acquisition and conversion to validate the "Invisible Maze" hook.

### Acquisition Analytics

| Metric | Value | Insights |
|--------|-------|----------|
| **Page Views** | 13.05K | High initial interest in the game concept/store presence. |
| **Install Attempts** | 347 | ~2.66% of viewers attempted to download. |
| **Successful Installs** | 301 | 86.7% Success Rate, indicating high build stability and Store listing clarity. |
| **First Time Launches** | 49 | 16.3% of installs converted to active players. |

### Visual Metrics Dashboard
![stats](<Screenshot 2026-04-06 211944.png>)
### Download Links

| Platform | Download |
|----------|----------|
| **Windows** | [Microsoft Store](#) *(Coming Soon)* |
| **Android** | [Google Play](#) *(Coming Soon)* |
| **iOS** | [App Store](#) *(Coming Soon)* |

---

## 🛠 Development Setup

### Prerequisites

```bash
# Install Flutter SDK
https://docs.flutter.dev/get-started/install

# Verify installation
flutter doctor

# Install dependencies
flutter pub get