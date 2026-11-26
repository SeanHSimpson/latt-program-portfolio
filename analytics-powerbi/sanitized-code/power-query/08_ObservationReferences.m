let
    Base = Table.SelectColumns(Observations, {"ItemID", "Reference"}),
    AddPubs = Table.AddColumn(Base, "Pubs", each if [Reference] = "Uncited" then {} else fnPublications([Reference]), type list),
    Expanded = Table.ExpandListColumn(Table.SelectColumns(AddPubs, {"ItemID", "Pubs"}), "Pubs"),
    NonNull = Table.SelectRows(Expanded, each [Pubs] <> null),
    Fields = Table.ExpandRecordColumn(NonNull, "Pubs", {"Prefix", "Series"}),
    Buffered = Table.Buffer(Fields),
    // Group every citation of a series under ONE label, using the prefix it is most often cited with.
    // Fixes unprefixed "21-101" and renamed pubs (old "AFI 91-203" vs current "DAFMAN 91-203").
    Known = Table.SelectRows(Buffered, each [Prefix] <> null),
    Counts = Table.Group(Known, {"Series", "Prefix"}, {{"n", each Table.RowCount(_), Int64.Type}}),
    Best = Table.Group(Counts, {"Series"}, {{"BestPrefix", each Table.Max(_, "n")[Prefix], type text}}),
    JoinBest = Table.NestedJoin(Buffered, {"Series"}, Best, {"Series"}, "B", JoinKind.LeftOuter),
    WithBest = Table.ExpandTableColumn(JoinBest, "B", {"BestPrefix"}),
    AddPub = Table.AddColumn(WithBest, "Publication", each
        let p = if [BestPrefix] <> null then [BestPrefix] else [Prefix]
        in if p = null then [Series] & " (no prefix)" else p & " " & [Series], type text),
    AddFamily = Table.AddColumn(AddPub, "Publication Type", each
        if [BestPrefix] <> null then [BestPrefix] else if [Prefix] <> null then [Prefix] else "Unknown", type text),
    Slim = Table.SelectColumns(AddFamily, {"ItemID", "Publication", "Publication Type"}),
    Dedup = Table.Distinct(Slim, {"ItemID", "Publication"}),
    Typed = Table.TransformColumnTypes(Dedup, {{"ItemID", Int64.Type}})
in
    Typed
