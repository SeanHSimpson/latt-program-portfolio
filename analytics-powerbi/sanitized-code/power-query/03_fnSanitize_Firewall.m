// Word-level non-attribution scrubber (Power Query M has no native regex engine).
// Redacts numbered organizational units (e.g., "[XX FW]", "101st Logistics Sq", "101 MXG/OPS"),
// site/installation names and acronyms (e.g., "Alpha Base", "SITE-A"), rank/title + personnel
// names (e.g., "Supervisor [Name]", "Mr. [Name]"), and email addresses.
// To extend for your organization, populate the site/unit lookup lists below.
(input as text) as text =>
let
    UnitAbbrev = {"AMU","AMXS","CMS","EMS","MXG","MXS","MXGI","MXGOI","FWI","MUNS","LRS","FW","WG","FS","FGS","FTS",
                  "OSS","OG","MSG","CES","SFS","MOS","MXK","CS","CONS","MDG","MDOS","AMDS","LRG","ABW","AW","RW","ARW",
                  "ATKS","RQS","RQW","MXOS","AMOS","SOW","SOG","SOS","SOMXG"},
    UnitWords = {"Fighter","Wing","Group","Squadron","Maintenance","Logistics","Readiness","Munitions","Aircraft","Operations",
                 "Generation","Component","Equipment","Mission","Support","Air","Base","Civil","Engineer","Security","Forces",
                 "Medical","Rescue","Communications","Contracting","Unit","Expeditionary"},
    Terminal = {"Wing","Group","Squadron","Unit"},
    Ranks = {"CMSgt","SMSgt","MSgt","TSgt","SSgt","SrA","A1C","Amn","AB","2Lt","1Lt","Capt","Maj","Col","Lt","Gen","Mr","Mrs","Ms","Dr","Sgt",
             "CMSGT","SMSGT","MSGT","TSGT","SSGT","SRA","CAPT","MAJ","COL"},
    NameStop = {"The","And","Or","Training","Supervisor","Supervisors","Promotion","Selects","Section","Shop","Flight","Position","Positions",
                "Level","Levels","Requirements","Equivalent","Authorization","Authorizations","Billet","Billets","Slot","Slots","Line","Lines"},
    Bases = {"AlphaBase","BravoBase","CharlieBase","DeltaBase","EchoBase","FoxtrotBase","GolfBase","HotelBase"},
    BaseAcr = {"SITE-A","SITE-B","SITE-C","SITE-D","SITE-E","AFB-A","AFB-B"},
    Phrases = {{"Alpha Base","AlphaBase"},{"Bravo Base","BravoBase"},{"Charlie Base","CharlieBase"},{"Delta Base","DeltaBase"},{"Echo Base","EchoBase"},{"Operating Base","Base"}},
    Punct = {".",",",";",":","!","?",")","(","[","]","""","'"},
    Digits = {"0".."9"},
    Upper = {"A".."Z"},
    Lower = {"a".."z"},

    // ---- token helpers ----
    SplitCore = (tok as text) as record =>
        let
            a = Text.TrimStart(tok, Punct),
            lead = Text.Start(tok, Text.Length(tok) - Text.Length(a)),
            c0 = Text.TrimEnd(a, Punct),
            trail0 = Text.End(a, Text.Length(a) - Text.Length(c0)),
            poss = Text.EndsWith(c0, "'s") and Text.Length(c0) > 2,
            c = if poss then Text.Start(c0, Text.Length(c0) - 2) else c0,
            trail = if poss then "'s" & trail0 else trail0
        in
            [Lead = lead, Core = c, Trail = trail],
    LeadingDigits = (t as text) as text => Text.Combine(List.FirstN(Text.ToList(t), each List.Contains(Digits, _))),
    IsNum = (t as text) as logical =>
        let pre = LeadingDigits(t), n = Text.Length(pre)
        in n >= 1 and n <= 4 and List.Contains({"", "st", "nd", "rd", "th", "ST", "ND", "RD", "TH"}, Text.Middle(t, n)),
    IsAbbrev = (t as text) as logical => List.Contains(UnitAbbrev, Text.Upper(Text.BeforeDelimiter(t, "/"))),
    SlashRest = (t as text) as text => if Text.Contains(t, "/") then "/" & Text.AfterDelimiter(t, "/") else "",
    IsGluedSeg = (seg as text) as logical =>
        let
            pre = LeadingDigits(seg), n = Text.Length(pre),
            rest = Text.Upper(Text.Middle(seg, n)),
            restNoOrd = if Text.Length(rest) > 2 and List.Contains({"ST", "ND", "RD", "TH"}, Text.Start(rest, 2)) then Text.Middle(rest, 2) else rest
        in
            n >= 1 and n <= 4 and rest <> "" and (List.Contains(UnitAbbrev, rest) or List.Contains(UnitAbbrev, restNoOrd)),
    IsGlued = (t as text) as logical => List.AnyTrue(List.Transform(Text.SplitAny(t, "/-"), IsGluedSeg)),
    IsName = (t as text) as logical =>
        Text.Length(t) >= 2
        and List.Contains(Upper, Text.Start(t, 1))
        and List.Contains(Lower, Text.Middle(t, 1, 1))
        and not List.Contains(Ranks, t)
        and not List.Contains(NameStop, t),
    IsBase = (t as text) as logical => List.Contains(Bases, t) or List.Contains(BaseAcr, t),
    // A bare 3-4 digit ordinal ("the 314th") is a unit number. Short ones ("24th month") are left alone.
    IsUnitOrdinal = (t as text) as logical =>
        let pre = LeadingDigits(t), n = Text.Length(pre)
        in n >= 3 and n <= 4 and List.Contains({"st", "nd", "rd", "th", "ST", "ND", "RD", "TH"}, Text.Middle(t, n)),

    // ---- tokenize ----
    Pre1 = List.Accumulate(Phrases, input, (s, p) => Text.Replace(s, p{0}, p{1})),
    Pre2 = Text.Replace(Text.Replace(Pre1, "#(tab)", " "), "#(lf)", " #(lf) "),
    Tok = List.Buffer(Text.Split(Pre2, " ")),
    N = List.Count(Tok),
    C = List.Buffer(List.Transform(Tok, SplitCore)),

    ChainEnd = (i as number) as number =>
        let
            cands = List.Generate(
                () => i + 1,
                each _ < N and _ <= i + 5 and List.Contains(UnitWords, C{_}[Core]) and (_ = i + 1 or C{_ - 1}[Trail] = ""),
                each _ + 1),
            terms = List.Select(cands, each List.Contains(Terminal, C{_}[Core]))
        in
            if List.IsEmpty(terms) then i else List.Max(terms),

    Step = (i as number) as record =>
        if i >= N then [Next = i, Out = ""] else
        let
            c = C{i},
            nx = if i + 1 < N then C{i + 1} else null,
            nx2 = if i + 2 < N then C{i + 2} else null,
            chain = if IsNum(c[Core]) and c[Trail] = "" then ChainEnd(i) else i,
            r =
                if Text.Contains(c[Core], "@") then
                    [Next = i + 1, Out = c[Lead] & "[EMAIL]" & c[Trail]]
                else if List.Contains(Ranks, c[Core]) and nx <> null and (c[Trail] = "" or c[Trail] = ".") and IsName(nx[Core]) then
                    let
                        two = nx[Trail] = "" and nx2 <> null and nx2[Lead] = "" and IsName(nx2[Core]),
                        last = if two then nx2 else nx
                    in
                        [Next = i + (if two then 3 else 2), Out = c[Lead] & "[PERSONNEL]" & last[Trail]]
                else if IsNum(c[Core]) and c[Trail] = "" and nx <> null and IsAbbrev(nx[Core]) then
                    [Next = i + 2, Out = c[Lead] & "[UNIT]" & SlashRest(nx[Core]) & nx[Trail]]
                else if chain > i then
                    [Next = chain + 1, Out = c[Lead] & "[UNIT]" & C{chain}[Trail]]
                else if IsGlued(c[Core]) then
                    [Next = i + 1, Out = c[Lead] & "[UNIT]" & c[Trail]]
                else if IsUnitOrdinal(c[Core]) then
                    [Next = i + 1, Out = c[Lead] & "[UNIT]" & c[Trail]]
                else if IsBase(c[Core]) then
                    let skipAfb = nx <> null and c[Trail] = "" and nx[Core] = "AFB"
                    in [Next = i + (if skipAfb then 2 else 1), Out = c[Lead] & "[INSTALLATION]" & (if skipAfb then nx[Trail] else c[Trail])]
                else
                    [Next = i + 1, Out = Tok{i}]
        in
            r,

    Pieces = List.Generate(
        () => [I = 0, S = Step(0)],
        each [I] < N,
        each [I = [S][Next], S = Step([S][Next])],
        each [S][Out]),
    Joined = Text.Combine(Pieces, " "),
    Result = Text.Trim(Text.Replace(Joined, " #(lf) ", "#(lf)"))
in
    if input = "" then "" else Result
