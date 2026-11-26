let
    Dates = List.RemoveNulls(Observations[Date Found]),
    MinD = List.Min(Dates),
    MaxD = List.Max({List.Max(Dates), Date.From(DateTime.LocalNow())}),
    StartD = #date(if Date.Month(MinD) >= 10 then Date.Year(MinD) else Date.Year(MinD) - 1, 10, 1),
    EndD = #date(if Date.Month(MaxD) >= 10 then Date.Year(MaxD) + 1 else Date.Year(MaxD), 9, 30),
    DayList = List.Dates(StartD, Duration.Days(EndD - StartD) + 1, #duration(1, 0, 0, 0)),
    T = Table.FromList(DayList, Splitter.SplitByNothing(), type table [Date = date]),
    AddCols = Table.AddColumn(T, "R", each
        let
            d = [Date], m = Date.Month(d), y = Date.Year(d),
            fy = if m >= 10 then y + 1 else y,
            fq = Number.IntegerDivide(Number.Mod(m + 2, 12), 3) + 1
        in
            [Year = y, Month = m, #"Month Name" = Date.ToText(d, "MMM", "en-US"),
             #"Month Start" = Date.StartOfMonth(d), #"Month Label" = Date.ToText(d, "MMM yyyy", "en-US"),
             #"Month Sort" = y * 100 + m,
             #"Fiscal Year" = fy, #"FY Label" = "FY" & Text.End(Text.From(fy), 2),
             #"Fiscal Quarter" = fq, #"FY Quarter" = "FY" & Text.End(Text.From(fy), 2) & " Q" & Text.From(fq),
             #"FY Quarter Sort" = fy * 10 + fq]),
    Expanded = Table.ExpandRecordColumn(AddCols, "R",
        {"Year", "Month", "Month Name", "Month Start", "Month Label", "Month Sort", "Fiscal Year", "FY Label", "Fiscal Quarter", "FY Quarter", "FY Quarter Sort"}),
    Typed = Table.TransformColumnTypes(Expanded, {
        {"Year", Int64.Type}, {"Month", Int64.Type}, {"Month Name", type text}, {"Month Start", type date},
        {"Month Label", type text}, {"Month Sort", Int64.Type}, {"Fiscal Year", Int64.Type}, {"FY Label", type text},
        {"Fiscal Quarter", Int64.Type}, {"FY Quarter", type text}, {"FY Quarter Sort", Int64.Type}})
in
    Typed
