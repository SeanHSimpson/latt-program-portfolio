let
    Kw = List.Buffer(Table.ToRecords(ThemeKeywords)),
    Delims = " .,;:!?()[]{}""'/\-_#&*+=<>|~`@$%^" & "#(lf)#(cr)#(tab)",
    Base = Table.SelectColumns(Observations, {"ItemID", "Details", "Recommendation"}),
    AddNorm = Table.AddColumn(Base, "Norm", each
        " " & Text.Combine(List.Select(Text.SplitAny(Text.Lower([Details] & " " & [Recommendation]), Delims), each _ <> ""), " ") & " ",
        type text),
    AddThemes = Table.AddColumn(AddNorm, "Themes", (r) =>
        let
            hits = List.Distinct(List.Transform(
                List.Select(Kw, (k) =>
                    if k[Match] = "prefix" then Text.Contains(r[Norm], " " & k[Keyword])
                    else Text.Contains(r[Norm], " " & k[Keyword] & " ")),
                each _[Theme]))
        in
            if List.IsEmpty(hits) then {"No Theme Match"} else hits),
    Slim = Table.SelectColumns(AddThemes, {"ItemID", "Themes"}),
    Expanded = Table.ExpandListColumn(Slim, "Themes"),
    Renamed = Table.RenameColumns(Expanded, {{"Themes", "Theme"}}),
    Typed = Table.TransformColumnTypes(Renamed, {{"ItemID", Int64.Type}, {"Theme", type text}})
in
    Typed
