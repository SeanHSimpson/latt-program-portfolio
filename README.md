# Program Management Portfolio: Logistics Assessment and Training Team (LATT)

> **Portfolio Note:** This repository contains **100% sanitized, unclassified structural artifacts** and synthetic `[Base Name]` / `[XX FW]` / `ASMT-001` examples. All internal government URLs, email addresses, host-unit identifiers, and personnel data have been removed.

## Live Interactive Portfolio Site (GitHub Pages)
- **Live Portfolio Website:** [https://seanhsimpson.github.io/latt-program-portfolio/](https://seanhsimpson.github.io/latt-program-portfolio/) (powered by [`index.html`](index.html)) featuring:
  - End-to-end **270-day program lifecycle** (T-90 intake through T+180 SLA follow-up)
  - Embedded **Interactive Power BI Executive Dashboard Mockup** ([`analytics-powerbi/demo/executive-dashboard-mockup.html`](analytics-powerbi/demo/executive-dashboard-mockup.html))
  - Embedded **Client-Side Non-Attribution Trend & HQ Action Analyzer** ([`analytics-powerbi/sanitized-code/html-prototype/enterprise-anon-tracker.html`](analytics-powerbi/sanitized-code/html-prototype/enterprise-anon-tracker.html))
  - Filterable **13-artifact UI & governance screenshot gallery** with zoom modal
  - **Business Rules to Automation Explorer** + Defense-to-Civilian PM crosswalk

---

## Executive Summary & Role Clarity
Conceived, designed, and scaled an enterprise operational assessment, training, and closed-loop corrective-action program from an abstract concept (`0-to-1`) into a standardized, repeatable multi-site operating system.

- **Role:** Program Founder & Program Manager (0-to-1 Charter & Governance, Cross-Functional RACI, Milestone Execution, Operational Risk Scoring, Non-Attribution Reporting Policy, Closed-Loop SLA Governance)
- **How Tools Were Built (PM + Low-Code / AI-Assisted Execution):** I am an operational **Program Manager**, not a traditional software developer. Operating in a resource-constrained government IT environment with zero dedicated engineering headcount, I authored the 45-page operating standard, risk matrices, privacy rules, and KPI definitions—and used Microsoft SharePoint/Power Platform alongside AI-assisted scripting to translate those program requirements into working field-capture tools, automated leave-behind workbooks, and Power BI dashboards.
- **Target Civilian Domains:** Program Management • Operations Program Management • Business Systems & Process Excellence • Defense Tech / Aerospace / Enterprise Operations

---

## 1. The Problem
Prior to formalization, site visits lacked standardized pre-visit intake, consistent field documentation, unified risk scoring, and post-visit accountability:
- Evaluations varied by team, making cross-site trend analysis unreliable.
- Compiling executive out-briefs and formal reports required heavy manual copy-paste after cutoff.
- Systemic issues requiring higher-headquarters intervention had no automated tracking from field capture to closure.

---

## 2. The Solution: End-to-End Operating System

```text
[90–7 Days Prior: Intake & Readiness]
  Milestone Tracker (Excel Dynamic Dashboard) + RFI Folder Structure
        │
        ▼
[On-Site Execution: Field Capture]
  Conditional Input Form (Power Apps / SharePoint)
  • Dynamic fields by Observation Type (Finding, Strength, Best Practice, RIA, Superior Performer)
  • Auto-calculated Operational Impact (Probability × Severity / Sustainability × Value)
        │
        ├──► [Automated Routing] ──► Staff Action Item Tracker (HQ Division Assignment & 180-Day Follow-Up)
        │
        ▼
[Reporting & Analytics]
  Automated Out-Brief & Written Report Builder + Semi-Annual Command Trend Pipeline
```

### Core Components Built
1. **45-Page Governance Standard Operating Procedure (`docs/LATT_SOP_Sanitized.docx`):**
   - Defines roles (Leadership Triad: Team Lead, Team Chief, Action Officer; Subject Matter Experts; Host Liaison), 90-day-to-180-day milestone gates, comms/OPSEC guardrails, quality-review gates, and standardized functional checklists across 6 focus areas.
2. **Conditional Observation Input Tool & Risk Matrices (`assets/finding-form.png`, `assets/impact-matrix-*.png`):**
   - Single SharePoint-backed input form that adapts dynamically across observation types (`Finding`, `Best Practice`, `Recommended Improvement Area`, `Superior Performer`, and `Strength`).
   - Built-in two-axis scoring matrices automatically compute **High / Moderate / Low Operational Impact** and enforce standalone data-quality fields.
3. **Automated Staff Action Pipeline (`assets/staff-action-tracker.png`):**
   - Items flagged for higher-headquarters support import automatically from field submissions into a dedicated tracking list with division ownership, target close dates, and a scheduled 180-day follow-up review.
4. **Dynamic Milestone Tracker (`assets/visit-milestone-tracker.png`):**
   - Standardized pre-visit and post-visit schedule calculator driven off Day 1 / Visit Completion dates, tracking 60+ milestone tasks across owners.
5. **Enterprise Power BI Analytics & Zero-Macro Excel Automation (`analytics-powerbi/`):**
   - Full technical case study ([`analytics-powerbi/CASE_STUDY.md`](analytics-powerbi/CASE_STUDY.md)), star-schema `.tmdl` model, modular Power Query M non-attribution ETL firewall (`fnCleanText`, `fnSanitize`, `fnPublications`, 10-theme keyword engine), DAX KPI & dynamic BLUF libraries, and zero-dependency browser demos:
     - Interactive Power BI Executive Dashboard Mockup: [`analytics-powerbi/demo/executive-dashboard-mockup.html`](analytics-powerbi/demo/executive-dashboard-mockup.html)
     - Interactive Client-Side Non-Attribution Analyzer: [`analytics-powerbi/sanitized-code/html-prototype/enterprise-anon-tracker.html`](analytics-powerbi/sanitized-code/html-prototype/enterprise-anon-tracker.html)
6. **Zero-VBA Site Leave-Behind & Modular Report Builder Slot (`analytics-powerbi/sanitized-code/power-query/excel-automation/`):**
   - Includes 4 sanitized Power Query M scripts (`01_WingVisit_Base.m`–`04_Wing_Strengths_BP.m`) powering macro-free Excel site leave-behind packets (`tblVisitFilter` dynamic site parameter, automatic PII nomination stripping, auto-sorted risk charts), plus a reserved modular slot in [`index.html`](index.html) for the upcoming sanitized **Automated Out-Brief & Written Report Builder** showcase.

---

## 3. Impact & Metrics Log *(Update `PORTFOLIO_METRICS` in `index.html` & Below Before 2028)*
- **Program Scale:** `[X]` site visits executed; `[X]` functional SMEs/evaluators onboarded; `[X]` standardized checklists deployed.
- **Process Efficiency:** Reduced post-visit out-brief and formal report compilation from `[X]` hours to `[Y]` hours via standardized exports and report automation.
- **Closed-Loop Accountability:** `[X]` Staff Action items routed and tracked; `[X]%` resolved/closed; `[X]` cross-command Best Practices and top-tier trends briefed to senior executives.

---

## 4. Portfolio Folder Setup Instructions
This `Portfolio_Sanitized` folder is staged cleanly so you can copy it to its own standalone directory (for example, `<your-projects-dir>/LATT-Portfolio/`) and initialize a clean Git repository there:
1. Copy `Portfolio_Sanitized/` to your standalone portfolio directory.
2. **Never copy** raw operational files from internal working folders into the standalone portfolio repo.
3. Verify all images, interactive HTML demos, and `README.md` before sharing externally or pushing to a public/private portfolio site.
