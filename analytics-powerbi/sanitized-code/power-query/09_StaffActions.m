let
    // ---------------------------------------------------------------------------
    // SOURCE: the "HQ Staff Action Items" SharePoint list (filled by the Power Automate flow).
    // ---------------------------------------------------------------------------
    RawSource =
        let
            Site = SharePoint.Tables(StaffActionsSiteUrl, [Implementation = "2.0", ViewMode = "All"]),
            Items = Table.SelectRows(Site, each [Title] = StaffActionsListName){0}[Items]
        in
            Items,

    // ---- NON-ATTRIBUTION FIREWALL: allow-list only ----
    // Deliberately left out: ObservationID (its prefix reveals the base), Base, Unit, Evaluator,
    // POC (a person's name) and the SharePoint Created By / Modified By columns.
    // A column that is missing in the source comes through empty instead of causing an error,
    // so check the result once: every column below should have values where you expect them.
    Keep = Table.SelectColumns(RawSource, {
        "ID", "Observation Type", "Date Found", "Function", "Section", "Reference", "Details",
        "Recommendation", "Finding Type", "Category", "Office Symbol", "Updates", "Last Updated",
        "Target Close Date", "Closed"}, MissingField.UseNull),
    Indexed = Table.AddIndexColumn(Keep, "RowNo", 1, 1, Int64.Type),

    // Everything a person can type into gets scrubbed, including the columns the POCs fill in.
    Scrubbed = {"Details", "Recommendation", "Reference", "Updates", "Category", "Office Symbol"},
    ChoiceText = {"Observation Type", "Function", "Section", "Finding Type"},

    Typed = Table.TransformColumns(Indexed,
        {{"Date Found", fnToDate, type nullable date},
         {"Last Updated", fnToDate, type nullable date},
         {"Target Close Date", fnToDate, type nullable date},
         {"Closed", fnToBool, type logical}}
        & List.Transform(Scrubbed, (c) => {c, each fnSanitize(fnCleanText(_)), type text})
        & List.Transform(ChoiceText, (c) => {c, each fnCleanText(_), type text})),

    SectionFixes = Table.ReplaceValue(Typed, "Avionic (Flightline)", "Avionics (Flightline)", Replacer.ReplaceValue, {"Section"}),

    // Neutral ID: SA-001, SA-002 ... from the SharePoint item ID (row number only if the list has no ID)
    AddNumber = Table.AddColumn(SectionFixes, "SA Number", each
        if [ID] = null or [ID] = "" then [RowNo] else Int64.From([ID]), Int64.Type),
    AddId = Table.AddColumn(AddNumber, "SA ID", each "SA-" & Text.PadStart(Text.From([SA Number]), 3, "0"), type text),

    // Blanks in the POC-filled columns get a label so they show up on charts as work still to do
    Relabeled = Table.TransformColumns(AddId, {
        {"Function", each if _ = "" then "Not Assigned" else _, type text},
        {"Section", each if _ = "" then "Not Assigned" else _, type text},
        {"Finding Type", each if _ = "" then "Not Classified" else _, type text},
        {"Observation Type", each if _ = "" then "Unspecified" else _, type text},
        {"Reference", each if _ = "" then "Uncited" else _, type text},
        {"Category", each if _ = "" then "Not Categorized" else _, type text},
        {"Office Symbol", each if _ = "" then "Unassigned" else Text.Upper(_), type text}}),

    // ---- Status columns (recalculated on every refresh) ----
    Today = Date.From(DateTime.LocalNow()),
    DueSoonDays = 30,
    StaleDays = 30,

    AddStatus = Table.AddColumn(Relabeled, "Status", each if [Closed] then "Closed" else "Open", type text),

    AddDue = Table.AddColumn(AddStatus, "Due Status", each
        if [Closed] then "Closed"
        else if [Target Close Date] = null then "No Target Date"
        else if [Target Close Date] < Today then "Overdue"
        else if [Target Close Date] <= Date.AddDays(Today, DueSoonDays) then "Due in 30 Days"
        else "On Track", type text),

    AddUpdate = Table.AddColumn(AddDue, "Update Status", each
        if [Closed] then "Closed"
        else if [Updates] = "" then "Awaiting First Update"
        else if [Last Updated] = null or Duration.Days(Today - [Last Updated]) > StaleDays then "Stale (30+ Days)"
        else "Current", type text),

    AddDaysOpen = Table.AddColumn(AddUpdate, "Days Open", each
        if [Closed] or [Date Found] = null then null else Duration.Days(Today - [Date Found]), Int64.Type),
    AddDaysToTarget = Table.AddColumn(AddDaysOpen, "Days to Target", each
        if [Closed] or [Target Close Date] = null then null else Duration.Days([Target Close Date] - Today), Int64.Type),
    AddTargetMonth = Table.AddColumn(AddDaysToTarget, "Target Month", each
        if [Target Close Date] = null then "No Target Date" else Date.ToText([Target Close Date], "yyyy-MM"), type text),

    // Sort-order helper columns (Column tools > Sort by column)
    AddDueSort = Table.AddColumn(AddTargetMonth, "Due Sort", each
        List.PositionOf({"Overdue", "Due in 30 Days", "On Track", "No Target Date", "Closed"}, [Due Status]) + 1, Int64.Type),
    AddUpdateSort = Table.AddColumn(AddDueSort, "Update Sort", each
        List.PositionOf({"Awaiting First Update", "Stale (30+ Days)", "Current", "Closed"}, [Update Status]) + 1, Int64.Type),

    // Link that opens the item's edit form in SharePoint
    AddLink = Table.AddColumn(AddUpdateSort, "Edit Link", each
        if [ID] = null or [ID] = "" then null
        else StaffActionsSiteUrl & "/Lists/" & Uri.EscapeDataString(StaffActionsListUrlName)
             & "/EditForm.aspx?ID=" & Text.From([SA Number]), type text),

    Final = Table.SelectColumns(AddLink, {
        "SA Number", "SA ID", "Status", "Closed", "Due Status", "Update Status",
        "Date Found", "Target Close Date", "Target Month", "Last Updated", "Days Open", "Days to Target",
        "Observation Type", "Function", "Section", "Finding Type", "Reference",
        "Details", "Recommendation", "Category", "Office Symbol", "Updates",
        "Edit Link", "Due Sort", "Update Sort"}),
    Buffered = Table.Buffer(Final)
in
    Buffered
