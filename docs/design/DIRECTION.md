# Afya Fit web app: design direction

Status: **draft for approval. No production code written.**
Scope: the whole logged-in web app (trainer, org admin, platform admin, client). Public landing and sign-in pages are out of scope.
Brief (from the owner, not self-authored): energetic, warm, dense; laptop and phone equally; accent colour is open; the logo stays.
Explorations: three directions were rendered on the trainer's Today screen. **C was chosen.** A (dark condensed, lanes) lost because it is the dark dev-tool face with a lime accent. B (coaching cards) lost because it is a four-card grid, too loose for a daily tool, and its coral fails contrast.

## 1. What this is

**Afya Fit is the sign system of a training venue.** Think stadium and airport wayfinding: a big time, a pictogram, a name, one action per row, and a "closed" sign on whatever is not open to you. Everything on screen is either a sign you can act on or a sign telling you why you cannot.

Category default refused: the white rounded SaaS dashboard with KPI cards, and the dark dev-tool table. Slop faces to watch for: "shadcn dashboard" (cards in boxes, six status colours) and "dark dev tool". This direction shares neither: one coloured field, no cards, one accent.

Look record: `app | printed | colour-field | expanded | orange | illustration | sidebar` (checked against history: differs on 4 of 6 columns).

## 2. Tokens

### Colour (one field, one accent)

| Token | Value | Use |
|---|---|---|
| `--field-0` | `#06402f` | sidebar, tab bar |
| `--field-1` | `#08503a` | canvas |
| `--field-2` | `#0b5f45` | hover and selected row |
| `--line` | `#e9f6ef` | rules: 3px structure, 1.5px at 40% for rows |
| `--ink` | `#ffffff` | text, outline tiles |
| `--ink-2` | `#c8e6d8` | secondary text |
| `--signal` | `#ff7a1a` | the one accent: next action, needs you now, read-only banner |
| `--signal-ink` | `#1c0d00` | text on `--signal` |
| `--paper` | `#ffffff` with `--field-0` ink | selected nav tile, "done" tile, dialogs |

Measured contrast: white on canvas 9.46, ink-2 on canvas 7.11, ink-2 on sidebar 8.85, signal-ink on signal 7.27, signal edge against canvas 3.63 (passes 3:1 for controls), against sidebar 4.52. **Signal is never used as small text on the green.** It is a fill with dark ink, or a large shape.

State without hue: done = white filled tile; next = orange tile; later = outline tile; overdue = an orange dot plus the word "Overdue"; closed = dashed tile plus a "PRO" tag. No red, amber or blue anywhere.

Dark mode: this is the only mode. `color-scheme: dark`. A light mode is not planned (the theme toggle in the top bar goes; it was daisyUI).

### Type

Single family: **Lexend Deca** (weights 400 to 900), chosen by the owner. Reason: its wide, even, geometric letterforms read as venue signage at heavy weights and stay legible at 14px, so one family covers the sign voice (800 to 900 caps for titles and times) and the dense UI voice (500 and 700). It is not on the default-reach list. It has no width axis, so the "wide" voice comes from the face and from tracking, not from a width setting.

Delivery: loaded from the Google Fonts CDN with `@import url("https://fonts.googleapis.com/css2?family=Lexend+Deca:wght@400..900&display=swap");` as the **first line of `app.css`**. `AGENTS.md` forbids external `<link>` tags in layouts, so the import lives in the CSS bundle. Fallback stack: `"Lexend Deca", "Segoe UI", system-ui, sans-serif`, metric-adjusted with `size-adjust` so the swap does not shift layout.
Trade-offs of a CDN: the visitor's browser contacts Google (a privacy note for the owner), the font fails offline (the fallback applies), and there is one extra connection on first load. Self-hosting remains an easy later change.

| Step | Size | Spec | Use |
|---|---|---|---|
| display | 48 (32 phone) | 900, caps, tracking -1% | page title |
| time | 28 (24 on phone) | 800, tabular | the big time or number in a row |
| title | 20 | 700 | row title, dialog title |
| body | 16 | 400 | reading text |
| ui | 14 | 500 / 700 | table cells, buttons (700, caps 13, +3%) |
| label | 12 | 700, caps, +8% | one label per group, never per section |
| tab | 12 | 700, caps | phone tab bar (floor is 12) |

Tabular figures everywhere (`font-variant-numeric: tabular-nums`). Measure 45 to 75 characters for any prose.

### Shape, space, elevation

- Radius family: 4px controls and banners, 6px tiles. Nothing larger. Circles only for status dots.
- Rules, not boxes: 3px `--line` under page headers and beside the sidebar; 1.5px at 40% between rows. No cards, no nested boxes.
- Elevation: only dialogs and menus float; they use `--paper` and a 2px ink offset, no blur.
- Spacing on a 4px base. Row padding 14 vertical, 26 horizontal (16 on phone). Hit targets 44px on phone, 32px minimum on desktop.

### Pictograms (the richness source)

A set of about 14 line pictograms in one hand: 48px grid, 3px stroke, round caps and joins, white on the field, no fills except the tile.
Set: calendar (Today), people (Clients), dumbbell (Workouts), bowl (Nutrition), bars (Progress), coach and whistle (Team), card (Billing), runner, scale, camera (photos), repeat (recurring task), lock-sign (closed), plus-person (add client), gear (Settings).
They are used as the row icon on every sign. **They replace heroicons in navigation and rows**; `<.icon>` stays for small utility glyphs in forms and menus (close, chevron, check).
Implementation: one `<.pictogram name="..." />` function component with inline SVG paths in a map, no sprite and no script.

## 3. Shell and grammar

Grammar: **sidebar of signs plus a sign-board page**. Each page is a header (title, one sentence of state) and a list of signs.

- **Desktop (1280+):** 132px sidebar (`--field-0`), each item a pictogram over a caps label, selected item inverted to white. User and plan at the bottom ("Wanjiru Njoroge, Owner, Free plan"). The banner, when present, sits above the header across the full canvas width.
- **Laptop (1024 to 1279):** same, sidebar 116px; the detail panel stacks under the list.
- **Tablet (768):** sidebar becomes a 72px pictogram-only rail with the label on focus and hover; title attributes present.
- **Phone (390):** bottom tab bar, 5 slots, labels at 12px. Trainer: Today, Clients, Workouts, Nutrition, More. "More" opens a sheet listing Progress, Settings (and Team, Billing for org admins). Rows stack: tile and time on one line, name and detail below, action full width.
- **Navigation by role**, one source of truth (`Authorization.can?` on a resource, not on role strings):

| Item | admin (platform) | org_admin | trainer | client |
|---|---|---|---|---|
| Today | | yes | yes | |
| Home | | | | yes |
| Clients | read | yes | yes | |
| Workouts | read | yes | yes | |
| Nutrition | read | yes (closed on Free) | yes (closed on Free) | |
| Progress | read | yes | yes | |
| Team | trainers | yes | | |
| Billing | yes | yes | | |
| Platform | yes | | | |
| Settings | yes | yes | yes | yes |

A closed item stays in the nav with a "PRO" tag so the feature is discoverable; a forbidden item (role) is not shown at all.

## 4. Signature: the sign draws itself

On first paint of a page and whenever a LiveView navigation mounts new rows, each pictogram draws its stroke (`stroke-dashoffset` 1 to 0, 0.9s ease-out, 80ms stagger between rows, max six rows animated). The row content is visible immediately; only the pictogram stroke animates. Reduced motion: strokes are drawn, no animation. Nothing loops. The "next" tile does not pulse.

Still frame (what a screenshot shows): all pictograms fully drawn. Off-screen rows do not animate until inserted.

## 5. The upgrade and read-only language

Three levels, one accent:

1. **Closed sign** (inline, a feature the plan does not include). A dashed tile with the feature pictogram, the feature name with a PRO tag, one sentence, one action.
2. **Limit dialog** (an action was blocked: LiveView received `{:error, {:upgrade_required, %{feature, required_tier}}}`). A dialog in `--paper`: title, what the plan allows now and what Pro allows, "Upgrade to Pro" and "Not now".
3. **Account banner** (read-only or grace period), full width above the page.
   - Grace (`past_due`, within 7 days): outlined bar, orange 3px top rule, white text. Full access.
   - Read-only (`past_due` after grace, `cancelled`, `expired`, or organization not active): solid orange bar with dark ink. Writes are paused.
   - Write controls are **not hidden**. They stay visible with `aria-disabled="true"` and a short reason beside the first one ("Paused until payment clears"). Clients never see a banner; their data stays usable.

Who sees which action: org admin gets "Update payment" or "Upgrade to Pro" (goes to Billing). A trainer gets the same text but names the person: "Ask Wanjiru Njoroge (owner) to upgrade." with no button. A platform admin sees organisation state, no upgrade action.

## 6. Content

Realistic data is Nairobi-based and uneven. Organisation: Njoroge Strength (Free plan, 3 of 3 clients). Owner: Wanjiru Njoroge (org_admin). Today: Thursday 29 Oct 2026, 14:10. Times are 24-hour. Currency is KES where shown. Prices are **not invented here**: plan prices come from the Paystack plan configuration; where a price is shown it is read from there, and until it exists the screens show the plan name only.

### 6.1 Shell

- Sidebar footer: "Wanjiru Njoroge" / "Owner · Free plan".
- Nav labels: Today, Clients, Workouts, Nutrition, Progress, Team, Billing, Platform, Settings, Home.
- Skip link: "Skip to content". Sign out: "Sign out" (in Settings and the user menu).
- Flash messages: success "Saved." / "Client added." / "Trainer removed. 3 clients moved to you." Errors state what happened and what to do; they never auto-dismiss.

### 6.2 Today (trainer, org admin)

- Title: "Today · Thu 29 Oct". Sentence: "1 done, 2 to go. Otieno missed Tuesday. Amina's check-in is due. Brian's plan ends in 3 days."
- Group "Sessions": rows with time, state word (Done, Next, Later), name, detail, action (Open log, Start check-in, Assign next).
- Group "Needs you": rows with an orange dot when overdue ("Overdue" word) and one action ("Message", "Start check-in", "Assign next plan").
- On Free (no calendar): "Sessions" shows client workouts due today. The group footer is a closed sign: "Calendar is on Pro. Book sessions and see them here."
- Empty: "Nothing scheduled today. Add a client workout to see it here." Action: "Assign a workout".
- Org admin additionally gets a quiet line under the sentence: "3 trainers, 41 clients, plan Pro." Nothing else.

### 6.3 Clients

- Title "Clients". Sentence: "3 of 3 places used on Free." (Pro: "12 of 25 places used on Pro.") Primary action "Add client".
- Row: pictogram tile, last-session time ("Tue 27 Oct"), name, detail ("Strength, week 6 of 12 · 2 tasks overdue"), action "Open".
- At the limit, the primary action becomes the limit dialog: "Client limit reached", "Free allows 3 clients. Pro allows 25.", "Upgrade to Pro", "Not now".
- Filter (in the URL): All, Active, Paused, Archived. Filtered empty: "No archived clients." with "Show all".
- First run empty: "Add your first client. They get a workout plan, a nutrition plan and a place to log progress." Action "Add client".
- Client detail: header with name and programme; groups "This week" (7 day marks, M to S), "Plans" (workout, nutrition with the closed sign on Free), "Tasks", "Progress". Row actions on the right; "Archive client" lives in a menu with a confirmation that names them: "Archive Otieno Odhiambo? Their plans and history stay. They stop appearing in your list."
- Add or edit form: labels above fields; fields First name, Last name, Email, Phone, Timezone; helper "We email an invitation when you save." Errors inline after leaving the field.
- Permission: another trainer's client, same organisation: "This client belongs to Brian Kariuki. Ask them or an owner for access."

### 6.4 Workouts

- Title "Workouts". Sentence "8 plans: 5 yours, 2 shared, 1 template." Tabs in the URL: Mine, Shared, Templates.
- Row: pictogram, "Updated 12 Oct", plan name, detail ("6 weeks · intermediate · 4 clients"), action "Open". Row menu: Duplicate, Edit, Delete.
- Detail: weeks and exercises as a table (Exercise, Sets, Reps, Rest); "Assign to client" opens a client picker limited to the user's reachable clients.
- Empty: "No workout plans yet. Start from a template or build your own." Actions "Use a template", "New plan".
- Delete confirm: "Delete Lower body B? It is assigned to 2 clients. They keep their history; the plan stops showing for new sessions."

### 6.5 Nutrition (closed on Free)

- On Free the page is one closed sign: tile dashed, "Nutrition plans" with PRO tag, "Meal plans with calories and macros for each client. Existing plans stay readable." Org admin: "Upgrade to Pro". Trainer: "Ask Wanjiru Njoroge (owner) to upgrade."
- On Pro: title "Nutrition". Rows: plan name, client, "2,100 kcal · protein 140 g", dates. Detail: meals table (Meal, Time, Calories, Notes).

### 6.6 Progress

- Title "Progress". Rows per client: name, last entry date, weight and change ("68.4 kg, down 1.1"), action "Open".
- Client progress page: entries table (Date, Weight, Body fat, Notes), numbers right-aligned, tabular. Group "Analytics" is a closed sign on Free ("Weight and body-fat change by month. On Pro."). Photos: closed sign on Free ("Progress photos. On Pro.").
- Empty: "No entries yet. Add the first measurement."

### 6.7 Team (org admin)

- Title "Team". Sentence "3 trainers, you included." Primary action "Add trainer".
- Table: Name, Email, Clients (right-aligned number), Last active, Role ("Owner", "Trainer"). Row menu for trainers: "Move clients", "Remove trainer". The owner row has no menu.
- Add trainer form: First name, Last name, Email. Helper "They get an email to set a password. They can see only the clients you assign them." Pro or Free: trainer count is not limited today.
- Remove confirm: "Remove Brian Kariuki? Their 14 clients, plans and tasks move to you. This is recorded in the activity log." Buttons "Remove trainer", "Keep".
- Success flash: "Trainer removed. 14 clients moved to you."
- Permission for a trainer reaching `/team`: 403 sign, see 6.10.

### 6.8 Billing (org admin; platform admin read)

- Title "Billing". Sentence by state: "Pro plan, renews 12 Nov." / "Payment failed on 14 Oct. Read-only until it clears." / "Cancelled. Access ends 12 Nov." / "Free plan."
- Group "Plan": rows Plan, Status (word plus orange dot only when not Active), Period ("12 Oct to 12 Nov"), Next charge. Actions by state: "Upgrade to Pro", "Update payment", "Cancel plan", "Reactivate".
- Group "Invoices": table (Number, Date, Amount KES, Status, right-aligned amounts). Empty: "No invoices yet."
- Cancel confirm: "Cancel Pro at the end of this period (12 Nov)? You keep access until then. After that the account becomes read-only; your data stays."
- Payment errors: "The payment provider did not accept the card. Nothing was charged. Try another card." with the Retry button and input kept.

### 6.9 Platform admin

- Title "Platform". Sentence "42 organisations." Table: Organisation, Plan, Status, Trainers, Clients. Row opens a read-only organisation page. No edit controls on organisation data.

### 6.10 Client home (web)

- Title "Home". Sentence "Your plan for this week." Rows: today's workout (Open log), nutrition plan (read), tasks ("Complete"). Client-facing words are second person. Empty: "Your trainer has not assigned anything yet."

### 6.11 Settings

- Groups: Profile, Password, Email, Notifications (existing fields). Org admin additionally: Organisation (name, logo). "Save" per group. Labels above fields; errors inline.

### 6.12 States nobody designs

| State | Treatment |
|---|---|
| Loading | Skeleton rows matching the real row (tile, time, two lines) after 300ms. No spinners over blank pages. |
| Error | A sign row: "That did not save. The server could not reach the database. Your changes are still in the form. Try again." with "Try again". |
| Offline | A thin bar: "You are offline. You can read what is loaded; changes will not save." |
| Permission (403) | Full page sign: lock tile, "Billing is for owners.", "Wanjiru Njoroge (owner) can change plans and payment. You can see your clients and plans." Link "Back to Today". |
| Not found (404) | "That page is not here, or it belongs to another organisation." Link "Back to Today". |
| Overflow | Names truncate with ellipsis and full name on hover and focus; a 10,000-row table pages 50 at a time; German or long labels wrap to two lines, never four. |
| Destructive | A dialog that names the object and says what stays; the confirm button repeats the verb. |

## 7. Voice

Plain, specific, short sentences, named people, numbers with units. Never "supercharge", "seamless", "unlock". Say what is blocked and what to do. Two exclamation marks in the whole product, both in first-run success flashes, or none.

## 8. How this maps to Phoenix (implementation constraints)

- All styling in Tailwind v4 in `app.css` with the tokens above as `@theme` variables; **no daisyUI** (remove the plugins from `app.css`, then delete `assets/vendor/daisyui*.js`). `AGENTS.md` rules hold: `<Layouts.app flash={@flash} current_scope={@current_scope}>`, `<.input>`, `<.icon>` for utility glyphs, no inline scripts, hooks in `assets/js`.
- New function components, in a new `AfyaFitWeb.SignComponents` imported through `html_helpers`: `pictogram/1`, `sign/1` (the row), `sign_group/1` (labelled list), `closed_sign/1`, `limit_dialog/1`, `account_banner/1`, `page_header/1`, `sign_button/1`, `tab_bar/1`. One component per concept; no LiveComponents.
- The shell's data comes from one `on_mount` hook that builds `AfyaFit.Authorization.Scope` (not today's bare `%{user: user}`), so nav items, banners and buttons call `Authorization.can?/4` and read `scope.tier` and billing state. **This also fixes `role == "trainer"` checks** in `layouts.ex`, `page_live.ex` and the trainer LiveViews, which is the prerequisite for promoting trainers to `org_admin`.
- LiveViews convert `{:error, :forbidden | :not_found | {:upgrade_required, _} | {:subscription_inactive, _}}` through one helper into flash, redirect or the limit dialog.
- Stream every list; every key element has a DOM id for tests.
- Every state in 6.12 gets a URL param in dev (`?state=empty`, `?state=error`, `?rows=10000`) for scanning, behind `dev_routes`.

## 8b. Rules learned from rendering Clients, Team and Billing

Scanned at 390 and 1440. These changed the spec:

- **Phone tab bar holds five slots, with "More".** Seven items (org admin) overflowed a 390px bar. Progress, Team and Billing move into the More sheet on phone only.
- **Tables become sign rows on phone.** A four-column table clipped at 390. Below 760px every table renders as sign rows (tile, headline value, detail), not a scrolling table.
- **Dialogs trap focus and make the page inert.** The page behind a dialog gets `inert`; the focus ring inside a `--paper` dialog is `--field-0`, not white (white was invisible).
- **Disabled controls stay readable.** `aria-disabled="true"` uses a dashed `--ink-2` border and `--ink-2` text (4.5:1 or better), never reduced opacity.
- **Tags are 12px minimum**, including the nav "PRO" tag.
- **The time column is 150px** so labels like "Past due" fit on one line.
- **Checked with Lexend Deca** on Clients, Team and Billing at 390 and 1440: no overflow; heavier caps read as signage.

## 9. Not decided, needs the owner

1. Font: decided. Lexend Deca from the Google Fonts CDN via `@import` in `app.css`.
2. Plan prices for the Billing and upgrade screens: not in the codebase. Until they exist the screens show plan names only.
3. The Free-plan "Sessions" group uses client workouts due today because Calendar is Pro. Confirm that is the intended Free experience.
4. Removing the theme toggle (this direction is dark only).
