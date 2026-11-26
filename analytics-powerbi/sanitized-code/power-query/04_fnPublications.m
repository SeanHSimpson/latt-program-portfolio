// Extracts publications from a free-text Reference. Returns a list of [Prefix, Series].
// Normalizes AFI->DAFI, AFMAN->DAFMAN, glued forms (AFI21-101_HQSUP), and infers TO for
// unprefixed tech-order numbers. Unprefixed two-part numbers (e.g. "21-101") come back with
// Prefix = null and are resolved later from how that series is usually cited.
(ref as text) as list =>
let
    Prefixes = {"DAFMAN","DAFPD","DAFI","AFMAN","AFPD","AFTTP","AFI","DODI","DODM","DOD","TO","DAF"},
    Norm = [DAFMAN = "DAFMAN", AFMAN = "DAFMAN", DAFI = "DAFI", AFI = "DAFI", DAFPD = "DAFPD", AFPD = "DAFPD",
            AFTTP = "AFTTP", DODI = "DoDI", DOD = "DoDI", DODM = "DoDM", TO = "TO", DAF = "DAFI"],
    Digits = {"0".."9"},
    Up0 = Text.Replace(Text.Upper(ref), "T.O.", "TO "),
    Up1 = List.Accumulate({"_", ",", ";", "(", ")", "/", "&", "#(lf)", "#(tab)"}, Up0, (s, ch) => Text.Replace(s, ch, " ")),
    // "DAFI-21-101" -> "DAFI 21-101", "AFI21-101" -> "AFI 21-101"
    Up1b = List.Accumulate(Prefixes, Up1, (s, p) => Text.Replace(s, p & "-", p & " ")),
    Up2 = List.Accumulate(Prefixes, Up1b, (s, p) => List.Accumulate(Digits, s, (s2, d) => Text.Replace(s2, p & d, p & " " & d))),
    Toks = List.Buffer(List.Select(List.Transform(Text.Split(Up2, " "), each Text.TrimEnd(Text.Trim(_), {".", ":"})), each _ <> "")),
    N = List.Count(Toks),
    IsDigit = (ch as text) => List.Contains(Digits, ch),
    Found = List.Transform({0 .. N - 1}, (k) =>
        let
            t = Toks{k},
            segs = Text.Split(t, "-"),
            prev = if k > 0 then Toks{k - 1} else "",
            hasPrefix = List.Contains(Prefixes, prev),
            startsDigit = Text.Length(t) > 0 and IsDigit(Text.Start(t, 1)),
            hasHyphen = List.Count(segs) >= 2 and List.AllTrue(List.Transform(segs, each _ <> "")),
            allNumeric = List.AllTrue(List.Transform(segs, each Text.Select(_, Digits) = _)),
            result =
                if not (startsDigit and hasHyphen) then null
                else if hasPrefix then
                    let
                        p = Record.Field(Norm, prev),
                        series = if p = "TO" then t else Text.Combine(List.FirstN(segs, 2), "-")
                    in [Prefix = p, Series = series]
                else if not allNumeric then [Prefix = "TO", Series = t]
                else if List.Count(segs) >= 3 then [Prefix = "TO", Series = t]
                else if Text.Length(segs{0}) >= 2 and Text.Length(segs{1}) >= 2 then [Prefix = null, Series = t]
                else null
        in
            result),
    Valid = List.RemoveNulls(Found),
    Distinct = List.Distinct(Valid)
in
    Distinct
