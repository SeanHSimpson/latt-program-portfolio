let
    // ---------------------------------------------------------------------------
    // SOURCE: the LATT Observations master list in SharePoint.
    // ---------------------------------------------------------------------------
    RawSource =
        let
            Site = SharePoint.Tables(SiteUrl, [Implementation = "2.0", ViewMode = "All"]),
            Items = Table.SelectRows(Site, each [Title] = ObservationsListName){0}[Items]
        in
            Items,

    // ---- NON-ATTRIBUTION FIREWALL: allow-list only. If a name differs in SharePoint, fix it here. ----
    Keep = Table.SelectColumns(RawSource, {
        "ID", "Base", "Observation Type", "Date Found", "Function", "Section", "Reference",
        "Details", "Recommendation", "Training/Corrective Action", "Safety", "Compliance",
        "Operational Impact", "Staff Action", "Finding Type", "Probability", "Severity",
        "Sustainability", "Value", "Reviewed"}),

    Renamed = Table.RenameColumns(Keep, {
        {"ID", "ItemID"}, {"Training/Corrective Action", "Corrective Action"}}),

    FreeText = {"Details", "Recommendation", "Corrective Action", "Reference"},
    ChoiceText = {"Base", "Observation Type", "Function", "Section", "Operational Impact", "Finding Type",
                  "Probability", "Severity", "Sustainability", "Value"},
    Bools = {"Safety", "Compliance", "Staff Action", "Reviewed"},

    Typed = Table.TransformColumns(Renamed,
        {{"ItemID", each Int64.From(_), Int64.Type},
         {"Date Found", fnToDate, type nullable date}}
        & List.Transform(FreeText, (c) => {c, each fnSanitize(fnCleanText(_)), type text})
        & List.Transform(ChoiceText, (c) => {c, each fnCleanText(_), type text})
        & List.Transform(Bools, (c) => {c, fnToBool, type logical})),

    // Known spelling fixes in choice values (extend as needed)
    SectionFixes = Table.ReplaceValue(Typed, "Avionic (Flightline)", "Avionics (Flightline)", Replacer.ReplaceValue, {"Section"}),

    // ---- Neutral assessment key: one assessment = one LATT visit to one base ----
    // ObservationID can't be used: newer entries get a separate ID per observation, which
    // counted 258 "assessments" instead of ~6. A visit is the run of dates at one base;
    // a gap of more than VisitGapDays starts a new visit. Base is used only inside these
    // steps and is removed below, so it never reaches the data model.
    VisitGapDays = 30,
    BaseFilled = Table.Buffer(Table.TransformColumns(SectionFixes,
        {{"Base", each if _ = null or _ = "" then "UNKNOWN" else _, type text}})),
    BaseList = List.Distinct(BaseFilled[Base]),
    StartsByBase = Record.FromList(
        List.Transform(BaseList, (b) =>
            let ds = List.Sort(List.Distinct(List.RemoveNulls(Table.SelectRows(BaseFilled, each [Base] = b)[Date Found])))
            in List.Select(ds, (d) => let i = List.PositionOf(ds, d) in i = 0 or Duration.Days(d - ds{i - 1}) > VisitGapDays)),
        BaseList),
    WithVisit = Table.AddColumn(BaseFilled, "VisitKey", (r) =>
        let s = if r[Date Found] = null then null
                else List.Max(List.Select(Record.Field(StartsByBase, r[Base]), (x) => x <= r[Date Found]))
        in (if s = null then "9999-12-31" else Date.ToText(s, "yyyy-MM-dd")) & "|" & r[Base], type text),
    VisitKeys = List.Sort(List.Distinct(WithVisit[VisitKey])),
    AssessByKey = Record.FromList(
        List.Transform(List.Positions(VisitKeys), (i) => "ASMT-" & Text.PadStart(Text.From(i + 1), 3, "0")),
        VisitKeys),
    WithAssess = Table.AddColumn(WithVisit, "Assessment", each Record.Field(AssessByKey, [VisitKey]), type text),
    NoRawId = Table.RemoveColumns(WithAssess, {"Base", "VisitKey"}),

    // ---- Derived classification ----
    AddNeutral = Table.AddColumn(NoRawId, "Neutral ID", each "LATT-" & Text.PadStart(Text.From([ItemID]), 4, "0"), type text),
    AddPositive = Table.AddColumn(AddNeutral, "Is Positive", each
        List.Contains({"Best Practice", "Superior Performer"}, [Observation Type]) or [Finding Type] = "Strength", type logical),
    AddCategory = Table.AddColumn(AddPositive, "Category", each
        if [Is Positive] then "Strength / Benchmark"
        else if [Observation Type] = "Recommended Improvement Area" then "Improvement Area"
        else "Finding", type text),

    // Raw values kept for data-quality checks before blanks are relabeled
    AddDQ = Table.AddColumn(AddCategory, "DQ Issues", each
        let
            r = _,
            checks = {
                {"Missing Function", r[Function] = ""},
                {"Missing Date", r[Date Found] = null},
                {"Missing Finding Type", r[Finding Type] = "" and not r[Is Positive]},
                {"Missing Operational Impact", r[Operational Impact] = "" and not r[Is Positive]},
                {"Missing Probability", r[Probability] = "" and not r[Is Positive]},
                {"Missing Severity", r[Severity] = "" and not r[Is Positive]},
                {"Missing Reference", r[Reference] = "" and not r[Is Positive]}
            }
        in
            Text.Combine(List.Transform(List.Select(checks, each _{1}), each _{0}), "; "), type text),
    AddDQCount = Table.AddColumn(AddDQ, "DQ Issue Count", each if [DQ Issues] = "" then 0 else List.Count(Text.Split([DQ Issues], "; ")), Int64.Type),

    Relabeled = Table.TransformRows(AddDQCount, (r) => Record.TransformFields(r, {
        {"Function", each if _ = "" then "Not Assigned" else _},
        {"Section", each if _ = "" then "Not Assigned" else _},
        {"Observation Type", each if _ = "" then "Unspecified" else _},
        {"Finding Type", each if _ = "" then (if r[Is Positive] then "Strength" else "Not Classified") else _},
        {"Operational Impact", each if _ = "" then "Not Assessed" else _},
        {"Probability", each if _ = "" then (if r[Is Positive] then "N/A" else "Not Assessed") else _},
        {"Severity", each if _ = "" then (if r[Is Positive] then "N/A" else "Not Assessed") else _},
        {"Sustainability", each if _ = "" then "N/A" else _},
        {"Value", each if _ = "" then "N/A" else _},
        {"Reference", each if _ = "" then "Uncited" else _}
    })),
    BackToTable = Table.FromRecords(Relabeled, Value.Type(AddDQCount)),

    AddPriority = Table.AddColumn(BackToTable, "Is Priority", each
        not [Is Positive] and ([Safety] or [Severity] = "Severe" or [Operational Impact] = "High"), type logical),

    AddRisk = Table.AddColumn(AddPriority, "Risk Level", each
        let p = [Probability], s = [Severity] in
        if not List.Contains({"Frequent", "Likely", "Occasional", "Unlikely"}, p)
           or not List.Contains({"Severe", "Significant", "Limited", "Minimal"}, s) then "Not Assessed"
        // Matches the LATT Operational Impact Matrix (Enterprise Operational Impact Matrix)
        else if (s = "Severe" and List.Contains({"Frequent", "Likely", "Occasional"}, p)) or (s = "Significant" and p = "Frequent") then "High"
        else if s = "Severe" or (s = "Significant" and List.Contains({"Likely", "Occasional"}, p))
             or (s = "Limited" and List.Contains({"Frequent", "Likely"}, p)) then "Moderate"
        else "Low", type text),

    // Sort-order helper columns (use Column tools > Sort by column in the model)
    AddSorts = Table.AddColumn(
        Table.AddColumn(
            Table.AddColumn(
                Table.AddColumn(AddRisk, "Risk Sort", each
                    List.PositionOf({"High", "Moderate", "Low", "Not Assessed"}, [Risk Level]) + 1, Int64.Type),
                "Probability Sort", each
                    let x = List.PositionOf({"Frequent", "Likely", "Occasional", "Unlikely"}, [Probability]) in if x < 0 then 9 else x + 1, Int64.Type),
            "Severity Sort", each
                let x = List.PositionOf({"Severe", "Significant", "Limited", "Minimal"}, [Severity]) in if x < 0 then 9 else x + 1, Int64.Type),
        "Impact Sort", each
            let x = List.PositionOf({"High", "Moderate", "Low"}, [Operational Impact]) in if x < 0 then 9 else x + 1, Int64.Type),

    Final = Table.ReorderColumns(AddSorts, {
        "ItemID", "Neutral ID", "Assessment", "Date Found", "Category", "Observation Type", "Function", "Section",
        "Finding Type", "Reference", "Details", "Recommendation", "Corrective Action",
        "Safety", "Compliance", "Staff Action", "Reviewed", "Operational Impact", "Probability", "Severity",
        "Risk Level", "Is Positive", "Is Priority", "Sustainability", "Value", "DQ Issues", "DQ Issue Count",
        "Risk Sort", "Probability Sort", "Severity Sort", "Impact Sort"}),
    Buffered = Table.Buffer(Final)
in
    Buffered
