# Competition Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a simple competition information module where students can browse categorized competitions with official links and summaries, while clubs/admins can upload and manage them.

**Architecture:** Keep competitions separate from activities because competitions do not support local signup, check-in, venue capacity, or settlement. Reuse the existing Flask route + Jinja template + MySQL script patterns and reuse current `club` accounts as competition uploaders.

**Tech Stack:** Flask 3, Jinja templates, PyMySQL, MySQL SQL scripts, Python `unittest` smoke checks.

---

### Task 1: Add Guard Tests

**Files:**
- Create: `tests/test_competition_feature.py`

- [ ] **Step 1: Write failing tests**

Create smoke tests that prove the expected routes, SQL schema fields, and no-signup detail page exist.

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m unittest tests.test_competition_feature -v`
Expected: FAIL because competition routes and templates do not exist yet.

### Task 2: Add Competition Schema and Seed Data

**Files:**
- Modify: `sql/02_create_tables.sql`
- Modify: `sql/03_insert_init_data.sql`
- Modify: `sql/99_bootstrap_workbench.sql`

- [ ] **Step 1: Create `competition` table**

Add table fields for club owner, category, organizer, official URL, summary, time range, status, and create time.

- [ ] **Step 2: Add realistic demo rows**

Add several published competition rows across math, literature, English, computer, entrepreneurship, art/design, and comprehensive categories. Summaries should read like official-page summaries, but remain demo data.

### Task 3: Add Competition Routes and Templates

**Files:**
- Create: `routes/competition_routes.py`
- Create: `templates/competitions.html`
- Create: `templates/competition_detail.html`
- Create: `templates/competition_manage.html`
- Modify: `app.py`
- Modify: `templates/base.html`

- [ ] **Step 1: Register routes**

Add list, detail, manage, create, update, and status-change endpoints.

- [ ] **Step 2: Build pages**

List and detail are available to all logged-in users. Manage/create/update/status are limited to admin and club users.

### Task 4: Improve Activity Categories

**Files:**
- Modify: `app.py`
- Modify: `routes/activity_routes.py`
- Modify: `templates/activities.html`
- Modify: `templates/activity_manage.html`
- Modify: `templates/activity_detail.html`
- Modify: `sql/03_insert_init_data.sql`
- Modify: `sql/99_bootstrap_workbench.sql`

- [ ] **Step 1: Add activity category choices**

Use config categories for filters and form selects. Keep existing `activity.category` column unchanged.

- [ ] **Step 2: Add category filter to activity list**

Filter activities by title, status, and category.

### Task 5: Verify

**Files:**
- No new files.

- [ ] **Step 1: Run smoke tests**

Run: `python -m unittest tests.test_competition_feature -v`
Expected: PASS.

- [ ] **Step 2: Compile Python files**

Run: `python -m compileall app.py core routes`
Expected: exit code 0.
