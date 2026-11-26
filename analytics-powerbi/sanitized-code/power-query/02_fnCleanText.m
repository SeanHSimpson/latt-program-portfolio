// Turns any SharePoint value (text, choice, lookup record, multi-choice list) into clean plain text:
// strips HTML tags, decodes HTML entities, repairs smart quotes / replacement characters.
(input as any) as text =>
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
    Chars = {
        {Character.FromNumber(65533), "'"}, {Character.FromNumber(8216), "'"}, {Character.FromNumber(8217), "'"},
        {Character.FromNumber(8220), """"}, {Character.FromNumber(8221), """"}, {Character.FromNumber(8209), "-"},
        {Character.FromNumber(160), " "}, {Character.FromNumber(8203), ""}
    },
    Fixed = List.Accumulate(Chars, Decoded, (s, p) => Text.Replace(s, p{0}, p{1})),
    NormNL = Text.Replace(Text.Replace(Fixed, "#(cr)#(lf)", "#(lf)"), "#(cr)", "#(lf)"),
    Result = Text.Trim(NormNL)
in
    Result
