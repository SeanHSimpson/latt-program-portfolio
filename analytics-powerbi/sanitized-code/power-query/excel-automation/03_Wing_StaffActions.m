// =============================================================================
// QUERY 3 (LOAD TO 'Staff Actions (MAJCOM)'!$A$5): LATT_Wing_StaffActions
// =============================================================================
// Pulls Staff Action items for the selected visit straight from the main
// Observations list (NO internal Enterprise HQ tracker updates/POC columns needed).
// Explicitly EXCLUDES Best Practices and Strengths even when SharePoint
// auto-flags Best Practices as Staff Action = TRUE.
// =============================================================================
let
    Source = LATT_WingVisit_Base,
    DefStaffActions = Table.SelectRows(Source, each [Staff Action] = true and not [IsPositive]),
    Sorted = Table.Sort(DefStaffActions, {
        {"Focus Area", Order.Ascending},
        {"_RiskSort", Order.Ascending},
        {"Obs ID", Order.Ascending}
    }),
    Final = Table.SelectColumns(Sorted, {
        "Obs ID", "Unit", "Date Found", "Focus Area", "Workcenter",
        "Finding Type", "Risk Level", "Safety Flag", "Reference",
        "Details", "Recommendation"
    })
in
    Final
