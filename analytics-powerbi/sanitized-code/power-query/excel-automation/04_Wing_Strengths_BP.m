// =============================================================================
// QUERY 4 (LOAD TO 'Strengths & Best Practices'!$A$5): LATT_Wing_Strengths_BP
// =============================================================================
// Includes Best Practices and Strengths for the selected visit.
// Superior Performer nominations are already stripped in LATT_WingVisit_Base.
// Keeps Best Practices cleanly separated from Deficiency Staff Actions.
// =============================================================================
let
    Source = LATT_WingVisit_Base,
    OnlyStrengths = Table.SelectRows(Source, each [IsPositive]),
    AddShareFlag = Table.AddColumn(OnlyStrengths, "Cross-Command Sharing", each
        if [Observation Type] = "Best Practice" then "Best Practice" else "Strength", type text),
    Sorted = Table.Sort(AddShareFlag, {
        {"Cross-Command Sharing", Order.Ascending},
        {"Focus Area", Order.Ascending},
        {"Workcenter", Order.Ascending},
        {"Obs ID", Order.Ascending}
    }),
    Final = Table.SelectColumns(Sorted, {
        "Obs ID", "Unit", "Date Found", "Cross-Command Sharing",
        "Focus Area", "Workcenter", "Details", "Recommendation"
    })
in
    Final
