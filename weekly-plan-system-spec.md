# 📘 Weekly Plan System Specification
*(Build Order for Claude Code Autonomous Dev Agent)*

> A lightweight, multilingual weekly planning system for small interconnected IT / game teams.
> Tech: React (Vite + TS + Tailwind) + Firebase (Auth + Firestore).
> Goal: every team member logs their weekly plan (daily or summary mode), updates progress anytime, and management can see blockers / off-days clearly.

---

## 0. 🔥 Agent Operating Rules (MANDATORY)
These instructions are for Claude Code.
Claude is acting as Lead Dev + Infra + Delivery.
Claude must follow these rules exactly:

1. Do not ask for permission.
2. End-to-end responsibility.
3. If something requires manual action, list clear numbered steps.
4. Include git workflow to push:
   - code → https://github.com/aunji/weekly-plan-system
   - spec + logs → https://github.com/aunji/ai-copilot-server/weekly-plan-system/
5. Maintain DEV_LOG.md (Asia/Bangkok timezone).
6. Never block waiting for approval.
7. Comments in English, i18n Thai/English.
8. Include Firebase Security Rules.
9. Deliver full runnable repo (React+Firebase).

---

## 1. 🎯 Product Overview
Weekly Plan System = lightweight planning & visibility tool for small game/IT teams.
Supports:
- Daily plan (Mon–Fri)
- Weekly summary (tasks + planned workdays)
- Realtime updates and blockers logging
- Visible to all team members, no admin hierarchy
- Two languages (TH/EN)
- Responsive design for mobile/desktop

---

## 2. 🧩 Tech Stack
| Layer | Stack |
|-------|--------|
| Frontend | React + Vite + TS + Tailwind |
| Backend | Firebase (Auth + Firestore) |
| Hosting | Static (FTP / Firebase Hosting) |
| i18n | react-i18next |
| Access | All users equal, transparent |

---

## 3. 🔁 Workflow Summary
- Monday: user fills weekly plan (daily or summary)
- Anytime: user can update progress (`update_logs`)
- Dashboard shows realtime blockers / off days
- No fixed “Friday” reporting; updates anytime

---

## 4. 📂 Firestore Structure
### users
```
{name, department_id, language, projects: []}
```
### projects
```
{name, active}
```
### weekly_plans
```
week, user_id, department_id, mode, daily_plan{}, weekly_summary{}, update_logs[], timestamps
```

---

## 5. 🔐 Security Rules
```js
match /weekly_plans/{planId} {
  allow read: if request.auth != null;
  allow create,update: if request.auth.uid == request.resource.data.user_id;
}
```
Everyone can view all, only owner edits.

---

## 6. 🌍 i18n
Provide both TH and EN dictionaries.

---

## 7. 📜 DEV_LOG.md
Example first entry:
```
2025-10-31 15:42 (Asia/Bangkok)
- Initialized Vite + React + Firebase integration.
- Created pages Dashboard, MyPlan, Profile.
- Added UpdateLogs.
Next: CSV export, mobile cards.
```

---

## 8. 🚀 Git Instructions
```bash
# create and push app repo
git init
git add .
git commit -m "feat: Weekly Plan System initial scaffold"
git branch -M main
git remote add origin git@github.com:aunji/weekly-plan-system.git
git push -u origin main

# push spec + logs to ai-copilot-server
cd ai-copilot-server
mkdir -p weekly-plan-system
cp ../weekly-plan-system/DEV_LOG.md weekly-plan-system/
cp ../weekly-plan-system-spec.md weekly-plan-system/
git add weekly-plan-system/
git commit -m "chore: add Weekly Plan System spec and dev log"
git push
```
