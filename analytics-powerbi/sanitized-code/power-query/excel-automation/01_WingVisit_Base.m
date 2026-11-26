// =============================================================================
// QUERY 1 (CONNECTION ONLY): LATT_WingVisit_Base
// =============================================================================
// Pulls directly from SharePoint "Observations Tool (Master List)", reads Base
// and optional Date range from the Excel table 'tblVisitFilter' on Wing Summary,
// cleans HTML, calculates Operational Impact Risk, and STRIPS OUT all
// "Superior Performer" nominations automatically.
//
// ONE-TIME LOAD SETTING: Home > Close & Load To... > "Only Create Connection"
// =============================================================================
let
    SiteUrl  = "https://example.invalid/sharepoint-site",
    ListName = "Observations Tool (Master List)",

    // ---- Helper functions (self-contained) ----
    fnCleanText = (input as any) as text =>
        let
            AsText =
                if input = null then ""
                else if Value.Is(input, type text) then input
                else if Value.Is(input, type list) then Text.Combine(List.Transform(input, each try Text.From(_) otherwise ""), "; ")
                else if Value.Is(input, type record) then
                    Text.From(Record.FieldOrDefault(input, "Value", Record.FieldOrDefault(input, "Title", Record.FieldOrDefault(input, "LookupValue", ""))))
                else try Text.From(input) otherwise "",
            Parts = Text.Split(AsText, "<"),
            NoTags =
                if List.Count(Parts) = 1 then AsText
                else List.First(Parts) & Text.Combine(
                    List.Transform(List.Skip(Parts), each if Text.Contains(_, ">") then Text.AfterDelimiter(_, ">") else "<" & _)),
            Entities = {
                {"&quot;", """"}, {"&#34;", """"}, {"&apos;", "'"}, {"&#39;", "'"}, {"&#58;", ":"},
                {"&#160;", " "}, {"&nbsp;", " "}, {"&lt;", "<"}, {"&gt;", ">"},
                {"&#8216;", "'"}, {"&#8217;", "'"}, {"&#8220;", """"}, {"&#8221;", """"},
                {"&#8211;", "-"}, {"&#8212;", "-"}, {"&amp;", "&"}
            },
            Decoded = List.Accumulate(Entities, NoTags, (s, p) => Text.Replace(s, p{0}, p{1})),
            Fixed = Text.Replace(Text.Replace(Decoded, "#(cr)#(lf)", "#(lf)"), "#(cr)", "#(lf)")
        in
            Text.Trim(Fixed),

    fnToBool = (v as any) as logical =>
        if v = null then false
        else if Value.Is(v, type logical) then v
        else List.Contains({"TRUE", "YES", "Y", "1"}, Text.Upper(Text.Trim(Text.From(v)))),

    fnToDate = (v as any) as nullable date =>
        if v = null or v = "" then null
        else if Value.Is(v, type date) then v
        else if Value.Is(v, type datetime) then Date.From(v)
        else if Value.Is(v, type datetimezone) then Date.From(DateTimeZone.RemoveZone(v))
        else try Date.From(DateTime.FromText(Text.From(v), [Culture = "en-US"]))
             otherwise try Date.FromText(Text.From(v), [Culture = "en-US"]) otherwise null,

    // ---- Read Base & Visit Date Window from Wing Summary parameter table ----
    ParamTbl   = Excel.CurrentWorkbook(){[Name = "tblVisitFilter"]}[Content],
    ParamRec   = Record.FromList(ParamTbl[Value], ParamTbl[Parameter]),
    TargetBase = Text.Upper(Text.Trim(try Text.From(Record.FieldOrDefault(ParamRec, "Base", "")) otherwise "")),
    StartDate  = fnToDate(Record.FieldOrDefault(ParamRec, "Visit Start Date", null)),
    EndDate    = fnToDate(Record.FieldOrDefault(ParamRec, "Visit End Date", null)),

    // ---- Pull from SharePoint Master List ----
    Site = SharePoint.Tables(SiteUrl, [Implementation = "2.0", ViewMode = "All"]),
    RawSource = Table.SelectRows(Site, each [Title] = ListName){0}[Items],

    Keep = Table.SelectColumns(RawSource, {
        "ObservationID", "Observation Type", "Base", "Unit", "Date Found",
        "Function", "Section", "Finding Type", "Reference", "Details",
        "Training/Corrective Action", "Recommendation",
        "Probability", "Severity", "Operational Impact", "Safety", "Staff Action"
    }, MissingField.UseNull),

    TextCols = {
        "ObservationID", "Observation Type", "Base", "Unit", "Function", "Section",
        "Finding Type", "Reference", "Details", "Training/Corrective Action",
        "Recommendation", "Probability", "Severity", "Operational Impact"
    },
    BoolCols = {"Safety", "Staff Action"},

    Typed = Table.TransformColumns(Keep,
        {{"Date Found", fnToDate, type nullable date}}
        & List.Transform(TextCols, (c) => {c, fnCleanText, type text})
        & List.Transform(BoolCols, (c) => {c, fnToBool, type logical})),

    FixSection = Table.ReplaceValue(Typed, "Avionic (Flightline)", "Avionics (Flightline)", Replacer.ReplaceValue, {"Section"}),

    // ---- Filter to Selected Base & Optional Date Window ----
    FilteredVisit = Table.SelectRows(FixSection, each
        (TargetBase = "" or Text.Upper(Text.Trim([Base])) = TargetBase)
        and (StartDate = null or ([Date Found] <> null and [Date Found] >= StartDate))
        and (EndDate = null or ([Date Found] <> null and [Date Found] <= EndDate))
    ),

    // ---- STRIP OUT SUPERIOR PERFORMER NOMINATIONS ----
    NoSupPerf = Table.SelectRows(FilteredVisit, each Text.Upper(Text.Trim([Observation Type])) <> "SUPERIOR PERFORMER"),

    // ---- Derived Classification & Risk Matrix (matches Power BI identically) ----
    AddIsPositive = Table.AddColumn(NoSupPerf, "IsPositive", each
        [Observation Type] = "Best Practice" or [Finding Type] = "Strength", type logical),

    AddRisk = Table.AddColumn(AddIsPositive, "Risk Level", each
        let p = [Probability], s = [Severity] in
        if [IsPositive] then "N/A"
        else if not List.Contains({"Frequent", "Likely", "Occasional", "Unlikely"}, p)
             or not List.Contains({"Severe", "Significant", "Limited", "Minimal"}, s) then "Not Assessed"
        else if (s = "Severe" and List.Contains({"Frequent", "Likely", "Occasional"}, p))
             or (s = "Significant" and p = "Frequent") then "High"
        else if s = "Severe"
             or (s = "Significant" and List.Contains({"Likely", "Occasional"}, p))
             or (s = "Limited" and List.Contains({"Frequent", "Likely"}, p)) then "Moderate"
        else "Low", type text),

    AddRiskSort = Table.AddColumn(AddRisk, "_RiskSort", each
        List.PositionOf({"High", "Moderate", "Low", "Not Assessed", "N/A"}, [Risk Level]) + 1, Int64.Type),

    AddSafetyTxt = Table.AddColumn(AddRiskSort, "Safety Flag", each if [Safety] then "Yes" else "No", type text),
    AddSATxt = Table.AddColumn(AddSafetyTxt, "MAJCOM Staff Action", each if [Staff Action] and not [IsPositive] then "Yes" else "No", type text),
    AddTrainedTxt = Table.AddColumn(AddSATxt, "Trained On-Site", each
        let ca = Text.Trim([#"Training/Corrective Action"]) in
        if not [IsPositive] and Text.Length(ca) > 0 and not List.Contains({"N/A", "NA", "None"}, ca) then "Yes" else "No", type text),

    CleanBlanks = Table.TransformColumns(AddTrainedTxt, {
        {"Function", each if _ = "" then "Not Assigned" else _, type text},
        {"Section", each if _ = "" then "Not Assigned" else _, type text},
        {"Finding Type", each if _ = "" then (if _ = "" then "Not Classified" else _) else _, type text},
        {"Reference", each if _ = "" then "Uncited" else _, type text}
    }),

    Renamed = Table.RenameColumns(CleanBlanks, {
        {"ObservationID", "Obs ID"},
        {"Function", "Focus Area"},
        {"Section", "Workcenter"}
    })
in
    Renamed
