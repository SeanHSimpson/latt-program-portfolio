// =============================================================================
// QUERY 2 (LOAD TO 'Deficiencies'!$A$5): LATT_Wing_Deficiencies
// =============================================================================
// Includes ONLY Findings & Recommended Improvement Areas for the selected visit.
// Excludes Best Practices, Strengths, and Superior Performers.
// =============================================================================
let
    Source = LATT_WingVisit_Base,
    OnlyDefs = Table.SelectRows(Source, each not [IsPositive]),
    Sorted = Table.Sort(OnlyDefs, {
        {"Focus Area", Order.Ascending},
        {"_RiskSort", Order.Ascending},
        {"Workcenter", Order.Ascending},
        {"Obs ID", Order.Ascending}
    }),
    Final = Table.SelectColumns(Sorted, {
        "Obs ID", "Unit", "Date Found", "Observation Type", "Focus Area", "Workcenter",
        "Finding Type", "Probability", "Severity", "Risk Level", "Safety Flag",
        "MAJCOM Staff Action", "Trained On-Site", "Reference",
        "Details", "Training/Corrective Action", "Recommendation"
    })
in
    Final
