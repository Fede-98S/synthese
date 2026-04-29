-- `'
-- This table will hold the functions:
ekddrama = {}

-- lpeg equivalent for string.gsub()
local function gsub(s, patt, repl)
  patt = lpeg.P(patt)
  patt = lpeg.Cs((patt / repl + 1)^0)
  return lpeg.match(patt, s)
end

-- some basic patterns:
local letters = lpeg.R("az", "AZ")
local ascii = lpeg.R("az", "AZ", "@@")
local dblbkslash = lpeg.Cs("\\")
local bsqbrackets = lpeg.Cs{ "[" * ((1 - lpeg.S"[]") + lpeg.V(1))^0 * "]" }
local bcbraces = lpeg.Cs{ "{" * ((1 - lpeg.S"{}") + lpeg.V(1))^0 * "}" }
local spce = lpeg.Cs(" ")
local spcenc = lpeg.P(" ")
local cmdstar = lpeg.Cs(spce * lpeg.P("*"))
local bsqbracketsii = lpeg.Cs(bsqbrackets^-2)
local bcbracesii = lpeg.Cs(bcbraces^-2)
local cmd = lpeg.Cs(dblbkslash * ascii^1 * cmdstar^-1)
local rawcmd = lpeg.Cs(dblbkslash * ascii^1)
local aftercmd = lpeg.Cs(lpeg.S("*[{,.?;:'`\"") + dblbkslash)
local cmdargs = lpeg.Cs(spce^-1 * bsqbracketsii * bcbracesii * bsqbrackets^-1)
local app = lpeg.Cs("app")
local lemrdg = lpeg.Cs(lpeg.Cs("lem") + lpeg.Cs("rdg"))
local choice = lpeg.Cs("choice")
local siccorr = lpeg.Cs(lpeg.Cs("sic") + lpeg.Cs("corr"))
local abbrexpan = lpeg.Cs(lpeg.Cs("abbr") + lpeg.Cs("expan"))
local origreg = lpeg.Cs(lpeg.Cs("orig") + lpeg.Cs("reg"))
local footnote = lpeg.Cs(lpeg.P("footnote"))
local note = lpeg.Cs(lpeg.P("note"))
local inlem = lpeg.Cs{ "<lem" * ((1 - (lpeg.P"<lem" + lpeg.P"</lem>")) + lpeg.V(1))^0 * "</lem>" }
local inanchor = lpeg.Cs{ "<anchor" * ((1 - (lpeg.P"<" + lpeg.P">")) + lpeg.V(1))^0 * ">" }
local inopeningnote = lpeg.Cs{ "<note" * ((1 - (lpeg.P"<" + lpeg.P">")) + lpeg.V(1))^0 * ">" }
local lnbrk = lpeg.Cs("\\\\")
local poemline = lpeg.Cs(lnbrk * spcenc^-1 * lpeg.S("*!")^-1 * bsqbrackets^-1 * spcenc^-1)
local poemlinebreak = lpeg.Cs(lnbrk * spcenc^-1 * (lpeg.P("&gt;") + lpeg.P("+")) * bsqbrackets^-1 * spcenc^-1)
local linegroup = lpeg.Cs{ "<lg" * ((1 - lpeg.S"<>") + lpeg.V(1))^0 * ">" }
local bclinegroup = lpeg.Cs(linegroup + lpeg.P("</lg>"))
local endpoem = lpeg.Cs(lnbrk * lpeg.S("*!") * bsqbrackets^-1) -- not used
local sections = lpeg.Cs(lpeg.P("book") + lpeg.P("part") + lpeg.P("chapter")
			    + lpeg.P("section") + lpeg.P("subsection")
			    + lpeg.P("subsubsection"))
local par =  lpeg.P(lpeg.P("\\par") * spce^0)
local parb = lpeg.P(lpeg.P("\\p@rb") * spce^0)
local para = lpeg.P(lpeg.P("\\p@ra") * spce^0)
local labelrefcmds = lpeg.Cs(lpeg.P("label")
			       + lpeg.P("linelabel")
			       + lpeg.P("lineref")
			       + lpeg.P("ref")
			       + lpeg.P("pageref")
			       + lpeg.P("vref")
			       + lpeg.P("vpageref"))
local citecmds = lpeg.Cs(lpeg.P("icite")
			    + lpeg.P("cite")
			    + lpeg.P("Cite")
			    + lpeg.P("cite *")
			    + lpeg.P("parencite")
			    + lpeg.P("Parencite")
			    + lpeg.P("parencite *")
			    + lpeg.P("footcite")
			    + lpeg.P("footcitetext")
			    + lpeg.P("textcite")
			    + lpeg.P("Textcite")
			    + lpeg.P("smartcite")
			    + lpeg.P("Smartcite")
			    + lpeg.P("autocite")
			    + lpeg.P("Autocite")
			    + lpeg.P("autocite *")
			    + lpeg.P("Autocite *"))

--
-- Bind to local variables
--
local next = next

-- General
local xmlids = {}
table.insert(xmlids, {xmlid = "scholars"} )

local function xmlidfound(element)
   for i = 1,#xmlids do
      if xmlids[i].xmlid == element then
	 return true
      end
   end
   return false
end

local function checkxmlid(str)
   if string.find(str, "^[0-9]")
      or string.find(str, "[%{%}%[%]%(%):; ]")
   then
      return false
   else
      return true
   end
end

-- Witnesses
local listWit = {}
-- Persons/Scholars
local listPerson = {}

local idsRend = {}
local shorthands = {}

local function isfound(table, value)
   for i = 1,#table do
      if table[i] == value then
	 return true
      end
   end
   return false
end

local function isintable(table, value)
   for i = 1,#table do
      if table[i].a == value then
	 return true
      end
   end
   return false
end

local function get_a_index(id, table)
   local idfound = nil
   for i = 1,#table
   do
      if table[i].a == id then
	 idfound = i
	 break
      end
   end
   return idfound
end

local function getindex(id, table)
   local idfound = nil
   for i = 1,#table
   do
      if table[i].xmlid == id then
	 idfound = i
	 break
      end
   end
   return idfound
end

function ekddrama.newwitness(id,
			    siglum,
			    description,
			    Settlement,
			    Institution,
			    Repository,
			    Collection,
			    Idno,
			    MsName,
			    OrigDate,
			    Locus)
   if xmlidfound(id)
   then
      tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
      	 ..id..
      	 "\" already exists as an xml:id. "
      	 ..
      	 "Please pick another id.}}")
   elseif not checkxmlid(id)
   then
      tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
      	 ..id..
      	 "\" is not a valid xml:id. \\MessageBreak "
      	 ..
      	 "Please pick another id.}}")
   else
      table.insert(xmlids, {xmlid = id})
      table.sort(xmlids, function(a ,b) return(#a.xmlid > #b.xmlid) end)
      table.insert(idsRend, {xmlid = id, abbr = siglum})
      table.sort(idsRend, function(a ,b) return(#a.xmlid > #b.xmlid) end)
      table.insert(listWit, {xmlid = id,
			     abbr = siglum,
			     detailsDesc = description,
			     msIdentifier = {
				settlement = Settlement,
				institution = Institution,
				repository = Repository,
				collection = Collection,
				idno = Idno,
				msName = MsName}
                             })
      local indexwit = getindex(id, listWit)
      if OrigDate ~= "" then
	 listWit[indexwit].history = {}
	 listWit[indexwit].history.origin = {origDate = OrigDate}
      end
      if Locus ~= "" then
	 listWit[indexwit].msContents = {}
	 listWit[indexwit].msContents.msItemStruct = {locus = Locus}
      end
   end
   return true
end

function ekddrama.newhand(id, witid, siglum, description)
   if xmlidfound(id) or not xmlidfound(witid)
   then
      tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
      	 ..id..
      	 "\" already exists as an xml:id. "
      	 ..
      	 "Please pick another id.}}")
   elseif not checkxmlid(id)
   then
      tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
      	 ..id..
      	 "\" is not a valid xml:id. \\MessageBreak "
      	 ..
      	 "Please pick another id.}}")
   else
      table.insert(xmlids, {xmlid = id})
      table.sort(xmlids, function(a ,b) return(#a.xmlid > #b.xmlid) end)
      table.insert(idsRend, {xmlid = id, abbr = siglum})
      table.sort(idsRend, function(a ,b) return(#a.xmlid > #b.xmlid) end)
      local indexwit = getindex(witid, listWit)
      -- listWit[indexwit].handDesc = {xmlid = id, abbr = siglum, handNote = description}
      if listWit[indexwit].handDesc == nil
      then
	 listWit[indexwit].handDesc = {}
      else
      end
      table.insert(listWit[indexwit].handDesc,
		   {xmlid = id, abbr = siglum, detailsDesc = description})
   end
   return true
end

function ekddrama.newshorthand(id, rend, xmlids)
   if isintable(shorthands, id)
   then
      tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
      	 ..id..
      	 "\" already exists as a shorthand. "
      	 ..
      	 "Please pick another shorthand.}}")
   else
      table.insert(shorthands, { a = id, b = rend, c = xmlids })
      table.sort(shorthands, function(a ,b) return(#a.a > #b.a) end)
      table.insert(idsRend, {xmlid = id, abbr = rend})
      table.sort(idsRend, function(a ,b) return(#a.xmlid > #b.xmlid) end)
   end
   return true
end

function ekddrama.newscholar(id,
			    siglum,
			    rawname,
			    Forename,
			    Surname,
			    AddName,
			    Note)
   if xmlidfound(id)
   then
      tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
      	 ..id..
      	 "\" already exists as an xml:id. "
      	 ..
      	 "Please pick another id.}}")
   elseif not checkxmlid(id)
   then
      tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
      	 ..id..
      	 "\" is not a valid xml:id. \\MessageBreak "
      	 ..
      	 "Please pick another id.}}")
   else
      table.insert(xmlids, {xmlid = id})
      table.sort(xmlids, function(a ,b) return(#a.xmlid > #b.xmlid) end)
      table.insert(idsRend, {xmlid = id, abbr = siglum})
      table.sort(idsRend, function(a ,b) return(#a.xmlid > #b.xmlid) end)
      if rawname ~= ""
      then
	 table.insert(listPerson, {xmlid = id,
				   abbr = siglum,
				   note = Note,
				   persName = {
				      name = rawname}
	 })
      else
	 table.insert(listPerson, {xmlid = id,
				   abbr = siglum,
				   note = Note,
				   persName = {
				      forename = Forename,
				      surname = Surname,
				      addName = AddName}
	 })
      end
   end
   return true
end

local xmlbibresource = nil

function ekddrama.addxmlbibresource(str)
   if string.find(str, "%.xml$")
   then
      xmlbibresource = str
   else
      xmlbibresource = str..".xml"
   end
   return true
end

function ekddrama.newsource(id, siglum)
   if xmlidfound(id)
   then
      tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
	    ..id..
	    "\" already exists as an xml:id. "
	    ..
	    "Please pick another id.}}")
   elseif not checkxmlid(id)
   then
      tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
      	 ..id..
      	 "\" is not a valid xml:id. \\MessageBreak "
      	 ..
      	 "Please pick another id.}}")
   else
      table.insert(xmlids, {xmlid = id})
      table.sort(xmlids, function(a ,b) return(#a.xmlid > #b.xmlid) end)
      table.insert(idsRend, {xmlid = id, abbr = siglum})
      table.sort(idsRend, function(a ,b) return(#a.xmlid > #b.xmlid) end)
   end
   return true
end


local familysep = nil

function ekddrama.setfamilysep(str)
   if str == "reset"
   then
      familysep = nil
   else
      familysep = str
   end
   return true
end

function ekddrama.getsiglum(str, opt)
   str = str..","
   str = string.gsub(str, "%s-(%,)", "%1")
   ctrl = str
   str = ","..str
   if opt == "tei" then
      for i = 1,#shorthands do
	 local tempa = string.gsub(shorthands[i].a, "([%-%.%_])", "%%%1")
	 str = string.gsub(str, tempa, shorthands[i].c)
      end
      for i = 1,#idsRend do
	 local tempb = string.gsub(idsRend[i].xmlid, "([%-%.%_])", "%%%1")
	 str  = string.gsub(str, "(%,%s?)"..tempb.."(%,)",
			    "%1#"..idsRend[i].xmlid.."%2")
	 ctrl = string.gsub(ctrl, tempb.."%,", "")
      end
      str = string.gsub(str, "^%,", "")
      str = string.gsub(str, "%,(%s-)([%#])", " %2")
      str = string.gsub(str, "%,$", "")
   else
      for i = 1,#idsRend do
	 local tempc = string.gsub(idsRend[i].xmlid, "([%-%.%_])", "%%%1")
	 local tempd = string.gsub(idsRend[i].abbr, "%,", "ekd@comma")
	 tempd = string.gsub(tempd, "%s+", "ekd@space")
	 str  = string.gsub(str, tempc.."%,", tempd)
	 ctrl = string.gsub(ctrl, tempc.."%,", "")
      end
      str = string.gsub(str, "^%,", "")
      if familysep ~= nil
      then
	 str = string.gsub(str, "%s+", familysep)
      end
      str = string.gsub(str, "ekd@comma", ",")
      str = string.gsub(str, "ekd@space", " ")
   end
   -- if string.find(ctrl, "[A-Za-z0-9]")
   if string.find(ctrl, "%S")
   then
      return "<??>"
   else
      return str
   end
end

-- Cast
local castList = {}

function ekddrama.newrole(id, role, RoleDesc, Actor)
	if xmlidfound(id) then
		tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
			.. id .. "\" already exists as an xml:id. "
			.. "Please pick another id.}}")
	elseif not checkxmlid(id) then
		tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
			.. id .. "\" is not a valid xml:id. \\MessageBreak "
			.. "Please pick another id.}}")
	else
		table.insert(xmlids, { xmlid = id })
		table.sort(xmlids, function(a, b) return #a.xmlid > #b.xmlid end)
		table.insert(castList, {
			xmlid = id,
			role = role,
			roleDesc = RoleDesc,
			actor = Actor
		})
        -- Define a LaTeX command for the role
        tex.sprint([[\expandafter\def\csname ]] .. id .. [[\endcsname{]] .. role .. "}")
	end
	return true
end

-- begin totei functions

local cmdtotags = {
   {a="textsuperscript", b="hi", c=" rend=\"sup\""},
   {a="textsubscript", b="hi", c=" rend=\"sub\""},
   {a="LRfootnote", b="note", c=" place=\"bottom\""},
   {a="RLfootnote", b="note", c=" place=\"bottom\""},
   {a="enquote *", b="quote", c=""},
   {a="marginpar", b="note", c=" place=\"margin\""},
   -- {a="footnote", b="note", c=" place=\"bottom\""},
   {a="enquote", b="quote", c=""},
   {a="prname *", b="span",
    c=" xml:lang=\"ar-Latn\" type=\"transliterated\""},
   {a="prname", b="span",
    c=" xml:lang=\"ar-Latn\" type=\"transliterated\" subtype=\"arabtex\""},
   {a="txtrans", b="s", c=" xml:lang=\"ar-Latn\" type=\"transliterated\""},
   {a="textbf", b="hi", c=" rend=\"bold\""},
   {a="textit", b="hi", c=" rend=\"italic\""},
   {a="textsc", b="hi", c=" rend=\"smallcaps\""},
   {a="textsf", b="hi", c=" rend=\"sf\""},
   {a="arbup", b="hi", c=" rend=\"sup\""},
   {a="txarb", b="foreign", c=" xml:lang=\"arb\""},
   {a="arb", b="span",
    c=" xml:lang=\"ar-Latn\" type=\"transliterated\" subtype=\"arabtex\""}
}

local texpatttotags = {
   {a="\\addentries%s+%[(.-)%]{(.-)}", b=""},
   {a="\\addentries%s+{(.-)}", b=""},
   {a="\\vmodulolinenumbers%s+%[(.-)%]", b=""},
   {a="\\vmodulolinenumbers%s+", b=""},
   {a="\\modulolinenumbers%s+%[(.-)%]", b=""},
   {a="\\modulolinenumbers%s+", b=""},
   {a="\\setverselinenums%s+{(.-)}{(.-)}", b=""},
   {a="\\resetvlinenumber%s+%[(.-)%]", b=""},
   {a="\\resetvlinenumber%s+", b=""},
   {a="\\resetlinenumber%s+%[(.-)%]", b=""},
   {a="\\resetlinenumber%s+", b=""},
   {a="\\ekdresethfmarks%s+", b=""},
   {a="\\indentpattern%s+{(.-)}", b=""},
   {a="\\localmaxlines%s+{(.-)}", b=""},
   {a="\\addtomaxlines%s+{(.-)}", b=""},
   {a="\\ekdnohfmarks%s+", b=""},
   {a="\\setmaxlines%s+{(.-)}", b=""},
   {a="\\nomaxlines%s+", b=""},
   {a="\\marginnote%s+(%b[])(%b{})(%b[])", b="<note place=\"margin\">ekd@ob%2ekd@cb</note>"},
   {a="\\marginnote%s+(%b{})(%b[])", b="<note place=\"margin\">ekd@ob%1ekd@cb</note>"},
   {a="\\marginnote%s+(%b[])(%b{})", b="<note place=\"margin\">ekd@ob%2ekd@cb</note>"},
   {a="\\marginnote%s+(%b{})", b="<note place=\"margin\">ekd@ob%1ekd@cb</note>"},
   {a="\\settowidth%s+{(.-)}{(.-)}", b=""},
   {a="\\teidirectE%s+(%b[]){(.-)}", b="<%2 ekd@os%1ekd@cs/>"},
   {a="\\teidirectE%s+{(.-)}", b="<%1/>"},
   {a="\\marginpar%s+(%b[])(%b{})", b="<note place=\"margin\">ekd@ob%2ekd@cb</note>"},
   {a="\\poemlines%s+{(.-)}", b=""},
   {a="\\pagebreak%s+%[[1-4]%]", b=""},
   {a="\\pagebreak%s+", b=""},
   {a="\\teidirect%s+(%b[]){(.-)}(%b{})", b="<%2 ekd@os%1ekd@cs>ekd@ob%3ekd@cb</%2>"},
   {a="\\teidirect%s+{(.-)}(%b{})", b="<%1>ekd@ob%2ekd@cb</%1>"},
   {a="\\altrfont%s+", b=""},
   {a="\\endmark%s+", b=""},
   {a="\\parnote%s+(%b[])(%b{})", b="<note>ekd@ob%2ekd@cb</note>"},
   {a="\\parnote%s+(%b{})", b="<note>ekd@ob%1ekd@cb</note>"},
   {a="\\ilabel%s+(%b{})", b=""},
   {a="\\unskip%s+", b=""},
   {a="\\ekdpb%s+%*?%[(.-)%]{(.-)}", b=""},
   {a="\\ekdpb%s+%*?{(.-)}", b=""},
   {a="\\ekdpb%s+%*\\?", b=""},
   {a="\\mbox%s+(%b{})", b="ekd@ob%1ekd@cb"},
   {a="\\App%s+(%b[])(%b{})(%b{})", b="\\app[ekd@os%1ekd@cs]{ekd@ob%2ekd@cbekd@ob%3ekd@cb}"},
   {a="\\App%s+(%b{})(%b{})", b="\\app{ekd@ob%1ekd@cbekd@ob%2ekd@cb}"},
   {a="\\choice[ekd@os%1ekd@cs]{ekd@ob%2ekd@cbekd@ob%3ekd@cb}"},
   {a="\\choice{ekd@ob%1ekd@cbekd@ob%2ekd@cb}"},
   {a="\\bayt%s+%+?%*?(%b{})(%b[])(%b{})",
    b="<l><seg type=\"hemistich\">ekd@ob%1ekd@cb</seg><seg type=\"tadwir\">ekd@os%2ekd@cs</seg><seg type=\"hemistich\">ekd@ob%3ekd@cb</seg></l>"},
   {a="\\bayt%s+%+?%*?(%b{})(%b{})",
    b="<l><seg type=\"hemistich\">ekd@ob%1ekd@cb</seg><seg type=\"hemistich\">ekd@ob%2ekd@cb</seg></l>"},
   {a="\\LR%s+(%b{})", b="ekd@ob%1ekd@cb"},
   {a="\\RL%s+(%b{})", b="ekd@ob%1ekd@cb"},
   {a="\\%=%=%=%s?", b="—"},
   {a="\\%-%-%-%s?", b="—"},
   {a="\\%=%=%s?", b="–"},
   {a="\\%-%-%s?", b="–"},
   {a="\\%=%/%s?", b="‐"},
   {a="\\%-%/%s?", b="‐"},
   {a="\\vin%s+", b=""},
   {a="\\uc%s+(%b{})", b="ekd@ob%1ekd@cb"},
   {a="\\set%s+(%b{}", b="<set><p>ekd@ob%2ekd@cb</p></set>"}
}

local envtotags = {
   {a="flushright", b="p", c=" rend=\"align(right)\""},
   {a="flushleft", b="p", c=" rend=\"align(left)\""},
   {a="quotation", b="quote", c=""},
   {a="txarabtr", b="p", c=" xml:lang=\"ar-Latn\" type=\"transliterated\""},
   {a="quoting", b="quote", c=""},
   {a="ekdpar", b="p", c=""},
   {a="txarab", b="p", c=" xml:lang=\"arb\""},
   {a="center", b="p", c=" rend=\"align(center)\""},
   {a="arab", b="p",
    c=" xml:lang=\"ar-Latn\" type=\"transliterated\" subtype=\"arabtex\""}
}

local close_p = {
   "p",
   "lg"
}

local forbid_xmlid = true

function ekddrama.newcmdtotag(cmd, tag, attr)
   if forbid_xmlid
   then
      attr = string.gsub(attr, "xml:id", "n") -- xml:id is not allowed here
   else
   end
   if isintable(cmdtotags, cmd)
   then
      local index = get_a_index(cmd, cmdtotags)
      table.remove(cmdtotags, index)
      table.insert(cmdtotags, {a = cmd, b = tag, c = " "..attr})
      table.sort(cmdtotags, function(a ,b) return(#a.a > #b.a) end)
   else
      table.insert(cmdtotags, {a = cmd, b = tag, c = " "..attr})
      table.sort(cmdtotags, function(a ,b) return(#a.a > #b.a) end)
   end
   return true
end

function ekddrama.newpatttotag(pat, repl)
   pat = string.gsub(pat, "([%[%]])", "%%%1")
   pat = string.gsub(pat, "%@b[1-9]", "(%%b{})")
   pat = string.gsub(pat, "%@s[1-9]", "(%%b[])")
   pat = string.gsub(pat, "%#[1-9]", "(.-)")
   repl = string.gsub(repl, "%#([1-9])", "%%%1")
   repl = string.gsub(repl, "%@b([1-9])", "ekd@ob%%%1ekd@cb")
   repl = string.gsub(repl, "%@s([1-9])", "ekd@os%%%1ekd@cs")
   if isintable(texpatttotags, pat)
   then
      local index = get_a_index(pat, texpatttotags)
      table.remove(texpatttotags, index)
      table.insert(texpatttotags, { a = pat, b = repl })
      table.sort(texpatttotags, function(a ,b) return(#a.a > #b.a) end)
   else
      table.insert(texpatttotags, { a = pat, b = repl })
      table.sort(texpatttotags, function(a ,b) return(#a.a > #b.a) end)
   end
   return true
end

function ekddrama.newenvtotag(env, tag, attr, closep)
   if forbid_xmlid
   then
      attr = string.gsub(attr, "xml:id", "n") -- xml:id is not allowed here
   else
   end
   if isintable(envtotags, env)
   then
      local index = get_a_index(env, envtotags)
      table.remove(envtotags, index)
      table.insert(envtotags, {a = env, b = tag, c = " "..attr, d = closep})
      table.sort(envtotags, function(a ,b) return(#a.a > #b.a) end)
   else
      table.insert(envtotags, {a = env, b = tag, c = " "..attr, d = closep})
      table.sort(envtotags, function(a ,b) return(#a.a > #b.a) end)
   end
   return true
end

-- Get values of attributes
local function get_attr_value(str, attr)
   str = str..","
   str = string.gsub(str, "%b{}", function(body)
			body = string.gsub(body, attr, attr.."@ekd")
			return string.format("%s", body)
   end)
   local attrval = string.match(str, "%f[%w]"..attr.."%s?%=%s?%b{}")
      or string.match(str, "%f[%w]"..attr.."%s?%=%s?.-%,")
      or ""
   attrval = string.gsub(attrval, attr.."%s?%=%s?(%b{})", function(bbraces)
			    bbraces = string.sub(bbraces, 2, -2)
			    return string.format("%s", bbraces)
   end)
   attrval = string.gsub(attrval, attr.."%s?%=%s?(.-)%s?%,", "%1")
   str = string.gsub(str, attr.."@ekd", attr)
   return attrval
end

local function xml_entities(str)
   str = string.gsub(str, "%<", "&lt;")
   str = string.gsub(str, "%>", "&gt;")
   return str
end

local function footnote_totei(str)
   str = gsub(str, dblbkslash * footnote * spce^-1 * bcbraces, "%1%2%3[]%4")
   str = gsub(str,
	      dblbkslash *
		 footnote *
		 spcenc^-1 *
		 bsqbrackets *
		 bcbraces *
		 spcenc^-1,
	      function(bkslash, cmd, opt, arg)
		 opt = string.sub(opt, 2, -2)
		 arg = string.sub(arg, 2, -2)
		 teitype = get_attr_value(opt, "type")
		 cmd = "note"
		 if teitype ~= "" then teitype = " type=\""..teitype.."\"" else end
		 return string.format("<%s%s place=\"bottom\">%s</%s>", cmd, teitype, arg, cmd)
   end)
   return str
end

local function note_totei(str)
   str = gsub(str,
	      dblbkslash *
		 note *
		 spcenc^-1 *
		 bsqbrackets *
		 bcbraces *
		 spcenc^-1,
	      function(bkslash, cmd, opt, arg)
		 opt = string.sub(opt, 2, -2)
		 arg = string.sub(arg, 2, -2)
		 teitype = get_attr_value(opt, "type")
		 if teitype ~= "" then teitype = " type=\""..teitype.."\"" else end
		 right = get_attr_value(opt, "labelb")
		 left = get_attr_value(opt, "labele")
		 if right == ""
		 then
		    return string.format("<%s>%s</%s>", cmd, arg, cmd)
		 else
		    if left ~= ""
		    then
		       return string.format(
			  "<%s%s target=\"#range(right(%s),left(%s))\">%s</%s><anchor xml:id=\"%s\"/>",
			  cmd, teitype, right, left, arg, cmd, right)
		    elseif left == ""
		    then
		       return string.format(
			  "<%s%s target=\"#right(%s)\">%s</%s><anchor xml:id=\"%s\"/>",
			  cmd, teitype, right, arg, cmd, right)
		    end
		 end
   end)
   return str
end

local function remove_extra_anchors(str)
   str = gsub(str, lpeg.Cs("</note>") * inanchor * inopeningnote, function(enote, anchor, bnote)
   			local id_one = string.gsub(anchor, "(%<anchor )(.-)(/%>)", "%2")
			id_one = string.sub(get_attr_value(tostring(id_one), "xml:id"), 2, -2)
   			local id_two = string.match(bnote, "target%=.-right%((.-)%)")
			id_two = string.gsub(tostring(id_two), ".-right%((.-)%)", "%1")
   			if id_one == id_two
   			then
   			   return string.format("%s%s", enote, bnote)
   			else
   			   return string.format("%s%s%s", enote, anchor, bnote)
   			end
   end)
   return str
end

local function app_totei(str)
   str = gsub(str,
	      dblbkslash *
		 app *
		 spcenc^-1 *
		 bsqbrackets *
		 bcbraces *
		 spcenc^-1,
	      function(bkslash, cmd, opt, arg)
		 opt = string.sub(opt, 2, -2)
		 arg = string.sub(arg, 2, -2)
		 opt = get_attr_value(opt, "type")
		 if opt ~= "" then opt = " type=\""..opt.."\"" else end
		 return app_totei(string.format("<%s%s>%s</%s>",
						cmd, opt, arg, cmd))
   end)
   return str
end

local function rdgGrp_totei(str)
   str = gsub(str,
	      dblbkslash *
		 lpeg.Cs("rdgGrp") *
		 spcenc^-1 *
		 bsqbrackets *
		 bcbraces *
		 spcenc^-1,
	      function(bkslash, cmd, opt, arg)
		 opt = string.sub(opt, 2, -2)
		 arg = string.sub(arg, 2, -2)
		 teitype = get_attr_value(opt, "type")
		 if teitype ~= "" then teitype = " type=\""..teitype.."\"" else end
		 if opt == ""
		 then
		    return rdgGrp_totei(string.format("<%s>%s</%s>",
						       cmd, arg, cmd))
		 else
		    return rdgGrp_totei(string.format("<%s%s>%s</%s>",
						       cmd, teitype, arg, cmd))
		 end
   end)
   return str
end

local function lem_rdg_totei(str)
   str = gsub(str,
	      spcenc^-1 *
		 dblbkslash *
		 lemrdg *
		 spcenc^-1 *
		 bsqbrackets *
		 bcbraces *
		 spcenc^-1,
	      function(bkslash, cmd, opt, arg)
		 opt = string.sub(opt, 2, -2)
		 arg = string.sub(arg, 2, -2)
		 -- opt = get_attr_value(opt, "wit")
		 --
		 teiwit = get_attr_value(opt, "wit")
		 if teiwit ~= "" then teiwit = " wit=\""..ekddrama.getsiglum(teiwit, "tei").."\"" else end
		 teisource = get_attr_value(opt, "source")
		 if teisource ~= "" then teisource = " source=\""..ekddrama.getsiglum(teisource, "tei").."\"" else end
		 teiresp = get_attr_value(opt, "resp")
		 if teiresp ~= "" then teiresp = " resp=\""..ekddrama.getsiglum(teiresp, "tei").."\"" else end
		 teitype = get_attr_value(opt, "type")
		 if teitype ~= "" then teitype = " type=\""..teitype.."\"" else end
		 --
		 if opt == ""
		 then
		    return lem_rdg_totei(string.format("<%s>%s</%s>",
						       cmd, arg, cmd))
		 else
		    -- opt = ekddrama.getsiglum(opt, "tei")
		    return lem_rdg_totei(string.format("<%s%s%s%s%s>%s</%s>",
						       cmd, teiwit, teisource, teiresp, teitype, arg, cmd))
		 end
   end)
   str = gsub(str, spcenc^-0 * dblbkslash * lemrdg * spcenc^-1 * bcbraces * spcenc^-1,
	      function(bkslash, cmd, arg)
		 arg = string.sub(arg, 2, -2)
		 return lem_rdg_totei(string.format("<%s>%s</%s>", cmd, arg, cmd))
   end)
   return str
end

local function choice_totei(str)
   str = gsub(str,
	      dblbkslash *
		 choice *
		 spcenc^-1 *
		 bsqbrackets *
		 bcbraces *
		 spcenc^-1,
	      function(bkslash, cmd, opt, arg)
		 opt = string.sub(opt, 2, -2)
		 arg = string.sub(arg, 2, -2)
		 opt = get_attr_value(opt, "type")
		 if opt ~= "" then opt = " type=\""..opt.."\"" else end
		 return choice_totei(string.format("<%s%s>%s</%s>",
						cmd, opt, arg, cmd))
   end)
   return str
end

local function sic_corr_totei(str)
   str = gsub(str,
	      spcenc^-1 *
		 dblbkslash *
		 siccorr *
		 spcenc^-1 *
		 bsqbrackets *
		 bcbraces *
		 spcenc^-1,
	      function(bkslash, cmd, opt, arg)
		 opt = string.sub(opt, 2, -2)
		 arg = string.sub(arg, 2, -2)
		 -- opt = get_attr_value(opt, "wit")
		 --
		 teiwit = get_attr_value(opt, "wit")
		 if teiwit ~= "" then teiwit = " wit=\""..ekddrama.getsiglum(teiwit, "tei").."\"" else end
		 teisource = get_attr_value(opt, "source")
		 if teisource ~= "" then teisource = " source=\""..ekddrama.getsiglum(teisource, "tei").."\"" else end
		 teiresp = get_attr_value(opt, "resp")
		 if teiresp ~= "" then teiresp = " resp=\""..ekddrama.getsiglum(teiresp, "tei").."\"" else end
		 teitype = get_attr_value(opt, "type")
		 if teitype ~= "" then teitype = " type=\""..teitype.."\"" else end
		 --
		 if opt == ""
		 then
		    return sic_corr_totei(string.format("<%s>%s</%s>",
						       cmd, arg, cmd))
		 else
		    -- opt = ekddrama.getsiglum(opt, "tei")
		    return sic_corr_totei(string.format("<%s%s%s%s%s>%s</%s>",
						       cmd, teiwit, teisource, teiresp, teitype, arg, cmd))
		 end
   end)
   str = gsub(str, spcenc^-0 * dblbkslash * siccorr * spcenc^-1 * bcbraces * spcenc^-1,
	      function(bkslash, cmd, arg)
		 arg = string.sub(arg, 2, -2)
		 return sic_corr_totei(string.format("<%s>%s</%s>", cmd, arg, cmd))
   end)
   return str
end

local function abbr_expan_totei(str)
   str = gsub(str,
	      spcenc^-1 *
		 dblbkslash *
		 abbrexpan *
		 spcenc^-1 *
		 bsqbrackets *
		 bcbraces *
		 spcenc^-1,
	      function(bkslash, cmd, opt, arg)
		 opt = string.sub(opt, 2, -2)
		 arg = string.sub(arg, 2, -2)
		 -- opt = get_attr_value(opt, "wit")
		 --
		 teiwit = get_attr_value(opt, "wit")
		 if teiwit ~= "" then teiwit = " wit=\""..ekddrama.getsiglum(teiwit, "tei").."\"" else end
		 teisource = get_attr_value(opt, "source")
		 if teisource ~= "" then teisource = " source=\""..ekddrama.getsiglum(teisource, "tei").."\"" else end
		 teiresp = get_attr_value(opt, "resp")
		 if teiresp ~= "" then teiresp = " resp=\""..ekddrama.getsiglum(teiresp, "tei").."\"" else end
		 teitype = get_attr_value(opt, "type")
		 if teitype ~= "" then teitype = " type=\""..teitype.."\"" else end
		 --
		 if opt == ""
		 then
		    return abbr_expan_totei(string.format("<%s>%s</%s>",
						       cmd, arg, cmd))
		 else
		    -- opt = ekddrama.getsiglum(opt, "tei")
		    return abbr_expan_totei(string.format("<%s%s%s%s%s>%s</%s>",
						       cmd, teiwit, teisource, teiresp, teitype, arg, cmd))
		 end
   end)
   str = gsub(str, spcenc^-0 * dblbkslash * abbrexpan * spcenc^-1 * bcbraces * spcenc^-1,
	      function(bkslash, cmd, arg)
		 arg = string.sub(arg, 2, -2)
		 return abbr_expan_totei(string.format("<%s>%s</%s>", cmd, arg, cmd))
   end)
   return str
end

local function orig_reg_totei(str)
   str = gsub(str,
	      spcenc^-1 *
		 dblbkslash *
		 origreg *
		 spcenc^-1 *
		 bsqbrackets *
		 bcbraces *
		 spcenc^-1,
	      function(bkslash, cmd, opt, arg)
		 opt = string.sub(opt, 2, -2)
		 arg = string.sub(arg, 2, -2)
		 -- opt = get_attr_value(opt, "wit")
		 --
		 teiwit = get_attr_value(opt, "wit")
		 if teiwit ~= "" then teiwit = " wit=\""..ekddrama.getsiglum(teiwit, "tei").."\"" else end
		 teisource = get_attr_value(opt, "source")
		 if teisource ~= "" then teisource = " source=\""..ekddrama.getsiglum(teisource, "tei").."\"" else end
		 teiresp = get_attr_value(opt, "resp")
		 if teiresp ~= "" then teiresp = " resp=\""..ekddrama.getsiglum(teiresp, "tei").."\"" else end
		 teitype = get_attr_value(opt, "type")
		 if teitype ~= "" then teitype = " type=\""..teitype.."\"" else end
		 --
		 if opt == ""
		 then
		    return orig_reg_totei(string.format("<%s>%s</%s>",
						       cmd, arg, cmd))
		 else
		    -- opt = ekddrama.getsiglum(opt, "tei")
		    return orig_reg_totei(string.format("<%s%s%s%s%s>%s</%s>",
						       cmd, teiwit, teisource, teiresp, teitype, arg, cmd))
		 end
   end)
   str = gsub(str, spcenc^-0 * dblbkslash * origreg * spcenc^-1 * bcbraces * spcenc^-1,
	      function(bkslash, cmd, arg)
		 arg = string.sub(arg, 2, -2)
		 return orig_reg_totei(string.format("<%s>%s</%s>", cmd, arg, cmd))
   end)
   return str
end

local function relocate_notes(str)
   str = gsub(str, inlem, function(arg)
		 local notes = {}
		 for i in string.gmatch(arg, "%<note.-%>.-%<%/note%>")
		 do
		    table.insert(notes, i)
		 end
		 allnotes = table.concat(notes)
		 arg = string.gsub(arg, "%<note.->.-%<%/note%>", "")
		 return string.format("%s%s", arg, allnotes)
   end)
   return str
end

local function linestotei(str)
   if not string.find(str, "^%s?<lg")
   then
      str = "\n<l>"..str
   end
   str = gsub(str, poemline * spcenc^0 * bclinegroup, "</l>\n%2")
   str = gsub(str, linegroup * -(spcenc^0 * bclinegroup), "%1\n<l>")
   str = gsub(str, lpeg.Cs("</lg>") * -(spcenc^0 * (bclinegroup + -1)), "%1\n<l>")
   -- str = gsub(str, poemline * spcenc^-1 * -1, "</l>\n")
   str = gsub(str, poemlinebreak, "<lb/> ")
   -- str = gsub(str, poemline * spcenc^-1 * lpeg.Cs("<lg"), "</l>%2")
   -- str = gsub(str, lpeg.Cs("</lg>") * spcenc^1 * -lpeg.P("<l"), "%1\n<l>")
   str = gsub(str, poemline, "</l>\n<l>")
   return str
end

local function stanzatotei(str)
   str = string.gsub(str, "\\begin%s?%{ekdstanza%}(%b[])(.-)\\end%s?%{ekdstanza%}", function(opt, arg)
			arg = string.gsub(arg, "\\par%s?", "")
			opt = string.sub(opt, 2, -2)
			teitype = get_attr_value(opt, "type")
			if teitype ~= "" then teitype = " type=\""..teitype.."\"" else end
			if opt == ""
			then
			   return string.format("<lg>%s</lg>", arg)
			else
			   return string.format("<lg%s>%s</lg>", teitype, arg)
			end
   end)
   str = string.gsub(str, "\\begin%s?%{ekdstanza%}(.-)\\end%s?%{ekdstanza%}", function(arg)
			arg = string.gsub(arg, "\\par%s?", "")
			return string.format("<lg>%s</lg>", arg)
   end)
   return str
end

-- better use lpeg: look into this later
local function versetotei(str)
   str = string.gsub(str, "\\begin%s?%{arabverse%}(%b[])(.-)\\end%s?%{arabverse%}", function(opt, arg)
			arg = string.gsub(arg, "\\par%s?", "")
			arg = gsub(arg, poemline, "")
			opt = string.sub(opt, 2, -2)
			if string.find(opt, "utf")
			then
			   return "\\p@rb "..string.format("<lg>%s</lg>", arg).."\\p@ra "
			else
			   return "\\p@rb "..string.format("<lg xml:lang=\"ar-Latn\" type=\"transliterated\" subtype=\"arabtex\">%s</lg>", arg).."\\p@ra "
			end
   end)
   str = string.gsub(str, "\\begin%s?%{arabverse%}(.-)\\end%s?%{arabverse%}", function(arg)
			arg = string.gsub(arg, "\\par%s?", "")
			arg = gsub(arg, poemline, "")
			return "\\p@rb "..string.format("<lg xml:lang=\"ar-Latn\" type=\"transliterated\" subtype=\"arabtex\">%s</lg>", arg).."\\p@ra "
   end)
   str = string.gsub(str, "\\begin%s?%{ekdverse%}(%b[])(.-)\\end%s?%{ekdverse%}", function(opt, arg)
			arg = string.gsub(arg, "\\par%s?", "")
			arg = string.gsub(arg, "\\begin%s?%{patverse%*?%}", "")
			arg = string.gsub(arg, "\\end%s?%{patverse%*?%}", "")
			arg = string.gsub(arg, "\\indentpattern%s?%b{}", "")
			opt = string.sub(opt, 2, -2)
			teitype = get_attr_value(opt, "type")
			if teitype ~= "" then teitype = " type=\""..teitype.."\"" else end
			if opt == ""
			then
			   return "\\p@rb "..linestotei(string.format("<lg>%s</lg>", arg)).."\\p@ra "
			else
			   return "\\p@rb "..linestotei(string.format("<lg%s>%s</lg>", teitype, arg)).."\\p@ra "
			end
   end)
   str = string.gsub(str, "\\begin%s?%{ekdverse%}(.-)\\end%s?%{ekdverse%}", function(arg)
			arg = string.gsub(arg, "\\par%s?", "")
			arg = string.gsub(arg, "\\begin%s?%{patverse%*?%}", "")
			arg = string.gsub(arg, "\\end%s?%{patverse%*?%}", "")
			arg = string.gsub(arg, "\\indentpattern%s?%b{}", "")
			return "\\p@rb "..linestotei(string.format("<lg>%s</lg>", arg)).."\\p@ra "
   end)
   str = string.gsub(str, "\\begin%s?%{verse%}%b[](.-)\\end%s?%{verse%}", function(arg)
			arg = string.gsub(arg, "\\par%s?", "")
			return "\\p@rb "..linestotei(string.format("<lg>%s</lg>", arg)).."\\p@ra "
   end)
   str = string.gsub(str, "\\begin%s?%{verse%}(.-)\\end%s?%{verse%}", function(arg)
			arg = string.gsub(arg, "\\par%s?", "")
			return "\\p@rb "..linestotei(string.format("<lg>%s</lg>", arg)).."\\p@ra "
   end)
   return str
end

local function envtotei(str)
   for i = 1,#envtotags
   do
      if envtotags[i].b ~= ""
      then
	 if isfound(close_p, envtotags[i].b) or envtotags[i].d == "yes"
	 then
	    str = gsub(str, lpeg.P("\\begin") * spcenc^-1 * lpeg.P("{")
			  * lpeg.Cs(envtotags[i].a) * lpeg.P("}")
			  * bsqbracketsii * bcbracesii * spcenc^-1,
		       "\\p@rb <"..envtotags[i].b..envtotags[i].c..">")
	    str = gsub(str, spcenc^-1 * lpeg.P("\\end") * spcenc^-1 * lpeg.P("{")
			  * lpeg.Cs(envtotags[i].a) * lpeg.P("}"),
		       "</"..envtotags[i].b..">\\p@ra ")
	 else
	    str = gsub(str, lpeg.P("\\begin") * spcenc^-1 * lpeg.P("{")
			  * lpeg.Cs(envtotags[i].a) * lpeg.P("}")
			  * bsqbracketsii * bcbracesii * spcenc^-1,
		       "<"..envtotags[i].b..envtotags[i].c..">")
	    str = gsub(str, spcenc^-1 * lpeg.P("\\end") * spcenc^-1 * lpeg.P("{")
			  * lpeg.Cs(envtotags[i].a) * lpeg.P("}"),
		       "</"..envtotags[i].b..">")
	 end
      else
	 str = gsub(str, lpeg.P("\\begin") * spcenc^-1 * lpeg.P("{")
		       * lpeg.Cs(envtotags[i].a) * lpeg.P("}")
		       * bsqbracketsii * bcbracesii * spcenc^-1,
		    "")
	 str = gsub(str, spcenc^-1 * lpeg.P("\\end") * spcenc^-1 * lpeg.P("{")
		       * lpeg.Cs(envtotags[i].a) * lpeg.P("}"),
		    "")
      end
   end
   str = gsub(str, lpeg.P("\\begin") * spcenc^-1 * lpeg.P("{")
		 * lpeg.Cs(ascii^1) * lpeg.P("}") * bsqbracketsii
		 * bcbracesii * spcenc^-1,
	      "<%1>")
   str = gsub(str, spcenc^-1 * lpeg.P("\\end") * spcenc^-1 * lpeg.P("{")
		 * lpeg.Cs(ascii^1) * lpeg.P("}") * bsqbracketsii
		 * bcbracesii,
	      "</%1>")
   return str
end

local function texpatttotei(str)
   for i = 1,#texpatttotags do
      while string.find(str, texpatttotags[i].a)
      do
	 str = string.gsub(str, texpatttotags[i].a, texpatttotags[i].b)
      end
   end
   str = string.gsub(str, "ekd@ob%{", "")
   str = string.gsub(str, "%}ekd@cb", "")
   str = string.gsub(str, "ekd@os%[", "")
   str = string.gsub(str, "%]ekd@cs", "")
   return str
end

local function icitetotei(str)
   str = gsub(str, lpeg.P("\\")
		 * citecmds
		 * spcenc^-1
		 * bsqbrackets
		 * bsqbrackets
		 * bcbraces
		 * (bsqbrackets + bcbraces)^-1,
	      function(cmd, pre, post, body, opt)
		 pre = string.sub(pre, 2, -2)
		 post = string.sub(post, 2, -2)
		 body = string.sub(body, 2, -2)
		 if not checkxmlid(body)
		 then
		    tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
				 ..body..
				 "\" is not a valid xml:id. \\MessageBreak "
				 ..
				 "Please pick another id.}}")
		 else
		 end
		 return string.format("%s <bibl corresp=\"#%s\"><biblScope>%s</biblScope></bibl>",
				      pre, body, post)
   end)
   str = gsub(str, lpeg.P("\\")
		 * citecmds
		 * spcenc^-1
		 * bsqbrackets
		 * bcbraces
		 * (bsqbrackets + bcbraces)^-1,
	      function(cmd, post, body, opt)
		 post = string.sub(post, 2, -2)
		 body = string.sub(body, 2, -2)
		 if not checkxmlid(body)
		 then
		    tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
				 ..body..
				 "\" is not a valid xml:id. \\MessageBreak "
				 ..
				 "Please pick another id.}}")
		 else
		 end
		 return string.format("<bibl corresp=\"#%s\"><biblScope>%s</biblScope></bibl>", body, post)
   end)
   str = gsub(str, lpeg.P("\\")
		 * citecmds
		 * spcenc^-1
		 * bcbraces
		 * (bsqbrackets + bcbraces)^-1,
	      function(cmd, body, opt)
		 body = string.sub(body, 2, -2)
		 if not checkxmlid(body)
		 then
		    tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
				 ..body..
				 "\" is not a valid xml:id. \\MessageBreak "
				 ..
				 "Please pick another id.}}")
		 else
		 end
		 return string.format("<ptr target=\"#%s\"/>", body)
   end)
   return str
end

local function cmdtotei(str)
   for i = 1,#cmdtotags
   do
      str = gsub(str, lpeg.P("\\") * lpeg.Cs(cmdtotags[i].a) * spcenc^-1 * bsqbrackets * -bcbraces, "\\%1%2{}")
      str = gsub(str, lpeg.P("\\") * lpeg.Cs(cmdtotags[i].a) * spcenc^-1 * -(bsqbrackets + bcbraces), "\\%1[]{}")
      str = string.gsub(str, "(\\"..cmdtotags[i].a..")%s?%*?(%b{})", "%1[]%2")
      str = string.gsub(str, "(\\"..cmdtotags[i].a..")%s?%*?(%b[])(%b{})",
			function(cmd, arg, body)
			   body = string.sub(body, 2, -2)
			   arg = string.sub(arg, 2, -2)
			   arg = string.gsub(arg, "(%b{})", function(braces)
						braces = string.sub(braces, 2, -2)
						return string.format("\"%s\"", braces)
			   end)
			   body = cmdtotei(body)
			   -- return string.format("<"..cmdtotags[i].b..cmdtotags[i].c.." %s>%s</"..cmdtotags[i].b..">", arg, body)
			   if cmdtotags[i].b ~= ""
			   then
			      return string.format("<"..cmdtotags[i].b..cmdtotags[i].c..">%s</" ..
						   cmdtotags[i].b..">", body)
			   else
			      return ""
			   end
      end)
   end
   -- temporarily:
   -- lacunae
   str = gsub(str,
	      spcenc^-1 *
	      dblbkslash *
		 lpeg.Cs(lpeg.P("lacunaStart") + lpeg.P("lacunaEnd")) *
		 spcenc^-1 *
		 bsqbrackets^-1 *
		 spcenc^-1,
		 function(bkslash, cmd, opt)
		    if opt == nil
		    then
		       return string.format("<%s/>", cmd)
		    else
		       opt = string.sub(opt, 2, -2)
		       teiwit = get_attr_value(opt, "wit")
		       if teiwit ~= "" then teiwit = " wit=\""..ekddrama.getsiglum(teiwit, "tei").."\"" else end
		       teisource = get_attr_value(opt, "source")
		       if teisource ~= "" then teisource = " source=\""..ekddrama.getsiglum(teisource, "tei").."\"" else end
		       if opt == ""
		       then
			  return string.format("<%s></%s>", cmd, cmd)
		       else
			  return string.format("<%s%s%s></%s>",
					       cmd, teiwit, teisource, cmd)
		       end
		    end
   end)
   str = string.gsub(str, "\\(getTEIxmlid)%s?(%b{})",
		     function(cmd, body)
			body = string.sub(body, 2, -2)
			teisiglum = ekddrama.getsiglum(body, "tei")
 			-- body = cmdtotei(body)
			return string.format("%s", teisiglum)
   end)
   str = string.gsub(str, "\\(getsiglum)%s?(%b{})",
		     function(cmd, body)
			body = string.sub(body, 2, -2)
			teisiglum = ekddrama.getsiglum(body, "tei")
			printsiglum = cmdtotei(ekddrama.getsiglum(body))
 			-- body = cmdtotei(body)
			return string.format("<ref target=\"%s\">%s</ref>",
					     teisiglum, printsiglum)
   end)
   str = string.gsub(str, "\\(gap)%s?(%b{})",
		     function(cmd, body)
			body = string.sub(body, 2, -2)
			teireason = get_attr_value(body, "reason")
			if teireason ~= "" then teireason = " reason=\""..teireason.."\"" else end
			teiunit = get_attr_value(body, "unit")
			if teiunit ~= "" then teiunit = " unit=\""..teiunit.."\"" else end
			teiquantity = get_attr_value(body, "quantity")
			if teiquantity ~= "" then teiquantity = " quantity=\""..teiquantity.."\"" else end
			teiextent = get_attr_value(body, "extent")
			if teiextent ~= "" then teiextent = " extent=\""..teiextent.."\"" else end
			return string.format("<gap%s%s%s%s/>", teireason, teiunit, teiquantity, teiextent)
   end)
   str = gsub(str, lpeg.P("\\") * labelrefcmds * spcenc^-1 * bcbraces,
	      function(cmd, body)
		 body = string.sub(body, 2, -2)
		 if not checkxmlid(body)
		 then
		    tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
				 ..body..
				 "\" is not a valid xml:id. \\MessageBreak "
				 ..
				 "Please pick another id.}}")
		 else
		 end
		 if string.find(cmd, "label")
		 then
		    return string.format("<anchor xml:id=\"%s\"/>", body)
		 else
		    return string.format("<ptr target=\"#%s\"/>", body)
		 end
   end)
   str = string.gsub(str, "\\(%a+)%s?%*?(%b[])(%b{})",
		     function(cmd, opt, body)
			body = string.sub(body, 2, -2)
			body = cmdtotei(body)
			return string.format("<%s>%s</%s>", cmd, body, cmd)
   end)
   str = string.gsub(str, "\\(%a+)%s?%*?(%b{})",
		     function(cmd, body)
			body = string.sub(body, 2, -2)
			body = cmdtotei(body)
			return string.format("<%s>%s</%s>", cmd, body, cmd)
   end)
   str = string.gsub(str, "\\([%{%}])", function(brace)
			if brace == "{"
			then
			   brace = "ekd@ob"
			else
			   brace = "ekd@cb"
			end
			return brace
   end)
   str = gsub(str, bcbraces, function(inbraces)
		 inbraces = string.sub(inbraces, 2, -2)
		 inbraces = cmdtotei(inbraces)
		 return inbraces
   end)
   str = string.gsub(str, "ekd@([oc])b", function(oc)
			if oc == "o"
			then
			   oc = "{"
			else
			   oc = "}"
			end
			return oc
   end)
   str = string.gsub(str, "(%s)(%>)", "%2")
   return str
end

local teiautopar = true

function ekddrama.setteiautopar(choice)
   if choice == "yes"
   then
      teiautopar = true
   else
      teiautopar = false
   end
   return true
end

local function partotei(str)
   if teiautopar
   then
      str = gsub(str, lpeg.P(lpeg.P("\\par") * spcenc^1)^1, "\\par ")
      str = gsub(str, ((para + parb) * par^-1)^2, "\\p@r ")
      str = string.gsub(str, "\\p@ra%s+", "<p>")
      str = string.gsub(str, "\\p@rb%s+", "</p>")
      str = string.gsub(str, "\\p@r%s+", "")
      str = string.gsub(str, "%s?\\par%s?", "<p>", 1)
      str = string.gsub(str, "(%<p%>)(%s-)(%<%/?div%d?)", "%3")
      str = string.gsub(str, "%s?\\par%s?", "</p><p>")
      str = string.gsub(str, "<p>%s?</p>", "")
      str = string.gsub(str, "(%<p%>)%s?(%</div%>)$", "%2")
      str = string.gsub(str, "(%<p%>)%s?$", "")
      str = string.gsub(str, "(<p>)%s?(<div.->)", "%2%1")
   else
      str = gsub(str, par + para + parb, "")
   end
   return str
end

local function self_close_tags(str)
   str = gsub(str, lpeg.P("<" * -lpeg.S("/"))
		 * lpeg.Cs(letters^1)
		 * lpeg.Cs((1 - lpeg.S"<>")^0)
		 * lpeg.P(">")
		 * lpeg.P("</")
		 * lpeg.Cs(letters^1)
		 * lpeg.P(">"), function(ftag, arg, ltag)
		    if ftag == ltag
		    then
		       return string.format("<%s%s/>", ftag, arg)
		    else
		    end
   end)
   return str
end

--headers and footers
local hfmarks = {}

function ekddrama.storehfmark(page, mk, opt)
   if opt == "endmk"
   then
      local emark = hfmarks[#hfmarks].mark
      table.insert(hfmarks, {a = page, mark = emark})
   else
      table.insert(hfmarks, {a = page, mark = mk})
   end
   return true
end

local printhfmarks = {
   HEL = true,
   HEC = true,
   HER = true,
   HOL = true,
   HOC = true,
   HOR = true,
   FOL = true,
   FOC = true,
   FOR = true,
   FEL = true,
   FEC = true,
   FER = true,
}

function ekddrama.nohfmark()
   printhfmarks.HEL = false
   printhfmarks.HEC = false
   printhfmarks.HER = false
   printhfmarks.HOL = false
   printhfmarks.HOC = false
   printhfmarks.HOR = false
   printhfmarks.FOL = false
   printhfmarks.FOC = false
   printhfmarks.FOR = false
   printhfmarks.FEL = false
   printhfmarks.FEC = false
   printhfmarks.FER = false
end

function ekddrama.resethfmark()
   printhfmarks.HEL = true
   printhfmarks.HEC = true
   printhfmarks.HER = true
   printhfmarks.HOL = true
   printhfmarks.HOC = true
   printhfmarks.HOR = true
   printhfmarks.FOL = true
   printhfmarks.FOC = true
   printhfmarks.FOR = true
   printhfmarks.FEL = true
   printhfmarks.FEC = true
   printhfmarks.FER = true
end

function ekddrama.printmark(str, mk)
   if printhfmarks[mk]
   then
      return str
   else
      printhfmarks[mk] = true
      return ""
   end
end

function ekddrama.gethfmark(page)
   local indexpage = get_a_index(page, hfmarks)
   if hfmarks[indexpage] ~= nil
   then
      return hfmarks[indexpage].mark
   else
      if page > hfmarks[#hfmarks].a
      then
	 return hfmarks[#hfmarks].mark
      else
	 for i=1,#hfmarks
	 do
	    if hfmarks[i].a > page
	    then
	       idfound = i
	       break
	    end
	 end
	 return hfmarks[idfound-1].mark or ""
      end
   end
end

-- divisions of the body text
local divdepth = {
   book = 1,
   part = 2,
   chapter = 3,
   section = 4,
   subsection = 5,
   subsubsection = 6
}

function ekddrama.mkdivdepths(...)
   divdepth = {}
   local num = 1
   for _, y in ipairs{...}
   do
      if y == "book" or "part" or "chapter"
	 or "section" or "subsection" or "subsubsection"
      then
	 divdepth[y] = num
	 num = num + 1
      else
      end
   end
   return true
end

-- LaTeX side: format the divisions
local fmtdiv = {}

function ekddrama.fmtdiv(n, fmtb, fmte)
   if isintable(fmtdiv, n)
   then
      local index = get_a_index(n, fmtdiv)
      table.remove(fmtdiv, index)
   else
   end
   table.insert(fmtdiv, { a = n, formatb = fmtb, formate = fmte} )
   return true
end

function ekddrama.getfmtdiv(n, pos)
   local index = get_a_index(n, fmtdiv)
   if index ~= nil
   then
      if pos == "b"
      then
	 return fmtdiv[index].formatb
      elseif pos == "e"
      then
	 return fmtdiv[index].formate
      end
   else
      return ""
   end
end

local ekddivs = true

function ekddrama.setekddivsfalse()
   ekddivs = false
end

local function ekddivs_totei(str)
   str = gsub(str, dblbkslash * lpeg.Cs("ekddiv") * spce^-1 * bcbraces,
	      function(bkslash, cmd, space, arg)
		 if ekddivs
		 then
		    arg = string.sub(arg, 2, -2)
		    teitype = get_attr_value(arg, "type")
		    tein = get_attr_value(arg, "n")
		    teihead = get_attr_value(arg, "head")
		    teidepth = get_attr_value(arg, "depth")
		    if teitype ~= "" then teitype = " type=\""..teitype.."\"" else end
		    if tein ~= "" then tein = " n=\""..tein.."\"" else end
		    if teidepth ~= ""
		    then
		       teidepth = " depth=\""..teidepth.."\""
		    else
		       teidepth = " depth=\"1\""
		    end
		    return string.format("\\p@rb <div%s%s%s><head>%s</head>\\p@ra ",
					 teitype, tein, teidepth, teihead)
		 else
		    return ""
		 end
   end)
   return str
end

local function section_totei(str)
   str = gsub(str, dblbkslash * sections * spce^-1 * bcbraces, "%1%2%3[]%4")
   str = gsub(str, dblbkslash * sections * spce^-1 * bsqbrackets * bcbraces,
	      function(bkslash, secname, space, opt, arg)
		 if ekddivs
		 then
		    return ""
		 else
		    ctr = divdepth[secname]
		    arg = string.sub(arg, 2, -2)
		    return string.format("\\p@rb <div%s type=\"%s\"><head>%s</head>\\p@ra ",
					 ctr, secname, arg)
		 end
       if ekdacts
		 then
		    return ""
		 else
		    ctr = divdepth[secname]
		    arg = string.sub(arg, 2, -2)
		    return string.format("\\p@rb <div%s type=\"%s\"><head>%s</head>\\p@ra ",
					 ctr, secname, arg)
		 end
       if ekdscenes
		 then
		    return ""
		 else
		    ctr = divdepth[secname]
		    arg = string.sub(arg, 2, -2)
		    return string.format("\\p@rb <div%s type=\"%s\"><head>%s</head>\\p@ra ",
					 ctr, secname, arg)
		 end
   end)
   return str
end

local used_ndivs = {}

local function close_ekddivs_at_end(str)
   local isdiv = false
   if string.find(str, "</div>$")
   then
      isdiv = true
      str = string.gsub(str, "(.*)(</div>)$", "%1")
   else
   end
   -- collect used depth numbers
   for i in string.gmatch(str, "<div .-depth%=\"%d\".->")
   do
      i = string.match(i, "depth=\"%d\"")
      i = string.match(i, "%d")
      if isintable(used_ndivs, i)
      then
      else
	 table.insert(used_ndivs, {a = i} )
      end
   end
   if next(used_ndivs) ~= nil
   then
      table.sort(used_ndivs, function(a ,b) return(#a.a > #b.a) end)
   else
   end
   local firstdiv = string.match(str, "<div .-depth%=\"%d\".->") or ""
   firstdiv = string.match(firstdiv, "depth%=\"%d\"") or ""
   firstdiv = string.match(firstdiv, "%d") or ""
   local lastdiv = string.match(string.reverse(str), ">.-\"%d\"%=htped.- vid<") or ""
   lastdiv = string.match(lastdiv, "\"%d\"%=htped") or ""
   lastdiv = string.match(lastdiv, "%d") or ""
   local firstdivindex = get_a_index(firstdiv, used_ndivs)
   local lastdivindex = get_a_index(lastdiv, used_ndivs)
   firstdivindex = tonumber(firstdivindex)
   lastdivindex = tonumber(lastdivindex)
   local closedivs = ""
   if isintable(used_ndivs, firstdiv)
   then
      while lastdivindex >= firstdivindex
      do
	 closedivs = closedivs.."</div>"
	 lastdivindex = lastdivindex - 1
      end
   end
   if isdiv
   then
      return str..closedivs.."</div>"
   else
      return str..closedivs
   end
end

local function close_ndivs_at_end(str)
   local isdiv = false
   if string.find(str, "</div>$")
   then
      isdiv = true
      str = string.gsub(str, "(.*)(</div>)$", "%1")
   else
   end
   -- collect used div numbers
   for i in string.gmatch(str, "<div[1-6]")
   do
      i = string.match(i, "[1-6]")
      if isintable(used_ndivs, i)
      then
      else
   	 table.insert(used_ndivs, {a = i} )
      end
   end
   if next(used_ndivs) ~= nil
   then
      table.sort(used_ndivs, function(a ,b) return(#a.a > #b.a) end)
   else
   end
   local firstdiv = string.match(str, "<div[1-6]") or ""
   firstdiv = string.match(firstdiv, "[1-6]") or ""
   local lastdiv = string.match(string.reverse(str), "[1-6]vid<") or ""
   lastdiv = string.match(lastdiv, "[1-6]") or ""
   local firstdivindex = get_a_index(firstdiv, used_ndivs)
   local lastdivindex = get_a_index(lastdiv, used_ndivs)
   firstdivindex = tonumber(firstdivindex)
   lastdivindex = tonumber(lastdivindex)
   local closedivs = ""
   if isintable(used_ndivs, firstdiv)
   then
      while lastdivindex >= firstdivindex
      do
	 closedivs = closedivs.."</div"..used_ndivs[lastdivindex].a..">"
	 lastdivindex = lastdivindex - 1
      end
   end
   if isdiv
   then
      return str..closedivs.."</div>"
   else
      return str..closedivs
   end
end

local function close_ekddivs_in_between(str)
   local maxdepth = 1
   for i in string.gmatch(str, "<div.-[Dd]epth=\"(%d)\".->", "%1")
   do
      if tonumber(i) > tonumber(maxdepth)
      then
	 maxdepth = i
      else
      end
   end
   for ndivi = 1, maxdepth
   do
      str = string.gsub(str, "(<div [^%>]-[Dd]epth%=\")("..ndivi..")(\".->)(.-)(<div [^%>]-depth%=\")(%d)(\".->)",
			function(bdivi, ndivi, edivi, between, bdivii, ndivii, edivii)
			   local firstdiv = ndivi
			   local lastdiv = ndivii
			   local firstdivindex = get_a_index(firstdiv, used_ndivs)
			   local lastdivindex = get_a_index(lastdiv, used_ndivs)
			   firstdivindex = tonumber(firstdivindex)
			   lastdivindex = tonumber(lastdivindex)
			   local closedivs = ""
			   if firstdivindex >= lastdivindex
			   then
			      while firstdivindex >= lastdivindex
			      do
				 closedivs = closedivs.."</div>"
				 firstdivindex = firstdivindex - 1
				 bdivii = string.gsub(bdivii, "depth", "Depth")
			      end
			   end
			   return string.format("%s%s%s%s%s%s%s%s",
						bdivi, ndivi, edivi, between,
						closedivs, bdivii, ndivii, edivii)
      end)
   end
   return str
end

local function clean_ekddivs(str)
   str = string.gsub(str, "(<div.-)(%s[Dd]epth%=\"%d\")(.->)", "%1%3")
   used_ndivs = {}
   return str
end

local function close_ndivs_in_between(str)
   for ndivi = 1, 6
   do
      str = string.gsub(str, "(<[Dd]iv)("..ndivi..")(.->)(.-)(<div)([1-6])(.->)",
			function(bdivi, ndivi, edivi, between, bdivii, ndivii, edivii)
			   local firstdiv = ndivi
			   local lastdiv = ndivii
			   local firstdivindex = get_a_index(firstdiv, used_ndivs)
			   local lastdivindex = get_a_index(lastdiv, used_ndivs)
			   firstdivindex = tonumber(firstdivindex)
			   lastdivindex = tonumber(lastdivindex)
			   local closedivs = ""
			   if firstdivindex >= lastdivindex
			   then
			      while firstdivindex >= lastdivindex
			      do
			   	 closedivs = closedivs.."</div"..used_ndivs[firstdivindex].a..">"
			   	 firstdivindex = firstdivindex - 1
				 bdivii = string.gsub(bdivii, "div", "Div")
			      end
			   end
			   return string.format("%s%s%s%s%s%s%s%s",
						bdivi, ndivi, edivi, between,
						closedivs, bdivii, ndivii, edivii)
   end)
   end
   return str
end

local function clean_latexdivs(str)
   str = string.gsub(str, "(<Div)([1-6])(.->)", "<div%2%3")
   used_ndivs = {}
   return str
end


--drama
--act
local ekdacts = true

function ekddrama.setekdactsfalse()
   ekdacts = false
end

local function ekdacts_totei(str)
   str = gsub(str, dblbkslash * lpeg.Cs("ekdact") * spce^-1 * bcbraces,
	      function(bkslash, cmd, space, arg)
		 if ekdacts
		 then
		    arg = string.sub(arg, 2, -2)
		    teitype = get_attr_value(arg, "type")
		    tein = get_attr_value(arg, "n")
		    teihead = get_attr_value(arg, "head")
		    teidepth = get_attr_value(arg, "depth")
		    if teitype ~= "" then teitype = " type=\""..teitype.."\"" else end
		    if tein ~= "" then tein = " n=\""..tein.."\"" else end
		    if teidepth ~= ""
		    then
		       teidepth = " depth=\""..teidepth.."\""
		    else
		       teidepth = " depth=\"1\""
		    end
		    return string.format("\\p@rb <div%s%s%s><head>%s</head>\\p@ra ",
					 teitype, tein, teidepth, teihead)
		 else
		    return ""
		 end
   end)
   return str
end

local function close_ekdacts_at_end(str)
   local isdiv = false
   if string.find(str, "</div>$")
   then
      isdiv = true
      str = string.gsub(str, "(.*)(</div>)$", "%1")
   else
   end
   -- collect used depth numbers
   for i in string.gmatch(str, "<div .-depth%=\"%d\".->")
   do
      i = string.match(i, "depth=\"%d\"")
      i = string.match(i, "%d")
      if isintable(used_ndivs, i)
      then
      else
	 table.insert(used_ndivs, {a = i} )
      end
   end
   if next(used_ndivs) ~= nil
   then
      table.sort(used_ndivs, function(a ,b) return(#a.a > #b.a) end)
   else
   end
   local firstdiv = string.match(str, "<div .-depth%=\"%d\".->") or ""
   firstdiv = string.match(firstdiv, "depth%=\"%d\"") or ""
   firstdiv = string.match(firstdiv, "%d") or ""
   local lastdiv = string.match(string.reverse(str), ">.-\"%d\"%=htped.- vid<") or ""
   lastdiv = string.match(lastdiv, "\"%d\"%=htped") or ""
   lastdiv = string.match(lastdiv, "%d") or ""
   local firstdivindex = get_a_index(firstdiv, used_ndivs)
   local lastdivindex = get_a_index(lastdiv, used_ndivs)
   firstdivindex = tonumber(firstdivindex)
   lastdivindex = tonumber(lastdivindex)
   local closedivs = ""
   if isintable(used_ndivs, firstdiv)
   then
      while lastdivindex >= firstdivindex
      do
	 closedivs = closedivs.."</div>"
	 lastdivindex = lastdivindex - 1
      end
   end
   if isdiv
   then
      return str..closedivs.."</div>"
   else
      return str..closedivs
   end
end

local function close_ekdacts_in_between(str)
   local maxdepth = 1
   for i in string.gmatch(str, "<div.-[Dd]epth=\"(%d)\".->", "%1")
   do
      if tonumber(i) > tonumber(maxdepth)
      then
	 maxdepth = i
      else
      end
   end
   for ndivi = 1, maxdepth
   do
      str = string.gsub(str, "(<div [^%>]-[Dd]epth%=\")("..ndivi..")(\".->)(.-)(<div [^%>]-depth%=\")(%d)(\".->)",
			function(bdivi, ndivi, edivi, between, bdivii, ndivii, edivii)
			   local firstdiv = ndivi
			   local lastdiv = ndivii
			   local firstdivindex = get_a_index(firstdiv, used_ndivs)
			   local lastdivindex = get_a_index(lastdiv, used_ndivs)
			   firstdivindex = tonumber(firstdivindex)
			   lastdivindex = tonumber(lastdivindex)
			   local closedivs = ""
			   if firstdivindex >= lastdivindex
			   then
			      while firstdivindex >= lastdivindex
			      do
				 closedivs = closedivs.."</div>"
				 firstdivindex = firstdivindex - 1
				 bdivii = string.gsub(bdivii, "depth", "Depth")
			      end
			   end
			   return string.format("%s%s%s%s%s%s%s%s",
						bdivi, ndivi, edivi, between,
						closedivs, bdivii, ndivii, edivii)
      end)
   end
   return str
end

local function clean_ekdacts(str)
   str = string.gsub(str, "(<div.-)(%s[Dd]epth%=\"%d\")(.->)", "%1%3")
   used_ndivs = {}
   return str
end

--scene
local ekdscenes = true

function ekddrama.setekdscenesfalse()
   ekdscenes = false
end

local function ekdscenes_totei(str)
   str = gsub(str, dblbkslash * lpeg.Cs("ekdscene") * spce^-1 * bcbraces,
	      function(bkslash, cmd, space, arg)
		 if ekdscenes
		 then
		    arg = string.sub(arg, 2, -2)
		    teitype = get_attr_value(arg, "type")
		    tein = get_attr_value(arg, "n")
		    teihead = get_attr_value(arg, "head")
		    teidepth = get_attr_value(arg, "depth")
		    if teitype ~= "" then teitype = " type=\""..teitype.."\"" else end
		    if tein ~= "" then tein = " n=\""..tein.."\"" else end
		    if teidepth ~= ""
		    then
		       teidepth = " depth=\""..teidepth.."\""
		    else
		       teidepth = " depth=\"1\""
		    end
		    return string.format("\\p@rb <div%s%s%s><head>%s</head>\\p@ra ",
					 teitype, tein, teidepth, teihead)
		 else
		    return ""
		 end
   end)
   return str
end

local function close_ekdscenes_at_end(str)
   local isdiv = false
   if string.find(str, "</div>$")
   then
      isdiv = true
      str = string.gsub(str, "(.*)(</div>)$", "%1")
   else
   end
   -- collect used depth numbers
   for i in string.gmatch(str, "<div .-depth%=\"%d\".->")
   do
      i = string.match(i, "depth=\"%d\"")
      i = string.match(i, "%d")
      if isintable(used_ndivs, i)
      then
      else
	 table.insert(used_ndivs, {a = i} )
      end
   end
   if next(used_ndivs) ~= nil
   then
      table.sort(used_ndivs, function(a ,b) return(#a.a > #b.a) end)
   else
   end
   local firstdiv = string.match(str, "<div .-depth%=\"%d\".->") or ""
   firstdiv = string.match(firstdiv, "depth%=\"%d\"") or ""
   firstdiv = string.match(firstdiv, "%d") or ""
   local lastdiv = string.match(string.reverse(str), ">.-\"%d\"%=htped.- vid<") or ""
   lastdiv = string.match(lastdiv, "\"%d\"%=htped") or ""
   lastdiv = string.match(lastdiv, "%d") or ""
   local firstdivindex = get_a_index(firstdiv, used_ndivs)
   local lastdivindex = get_a_index(lastdiv, used_ndivs)
   firstdivindex = tonumber(firstdivindex)
   lastdivindex = tonumber(lastdivindex)
   local closedivs = ""
   if isintable(used_ndivs, firstdiv)
   then
      while lastdivindex >= firstdivindex
      do
	 closedivs = closedivs.."</div>"
	 lastdivindex = lastdivindex - 1
      end
   end
   if isdiv
   then
      return str..closedivs.."</div>"
   else
      return str..closedivs
   end
end

local function close_ekdscenes_in_between(str)
   local maxdepth = 1
   for i in string.gmatch(str, "<div.-[Dd]epth=\"(%d)\".->", "%1")
   do
      if tonumber(i) > tonumber(maxdepth)
      then
	 maxdepth = i
      else
      end
   end
   for ndivi = 1, maxdepth
   do
      str = string.gsub(str, "(<div [^%>]-[Dd]epth%=\")("..ndivi..")(\".->)(.-)(<div [^%>]-depth%=\")(%d)(\".->)",
			function(bdivi, ndivi, edivi, between, bdivii, ndivii, edivii)
			   local firstdiv = ndivi
			   local lastdiv = ndivii
			   local firstdivindex = get_a_index(firstdiv, used_ndivs)
			   local lastdivindex = get_a_index(lastdiv, used_ndivs)
			   firstdivindex = tonumber(firstdivindex)
			   lastdivindex = tonumber(lastdivindex)
			   local closedivs = ""
			   if firstdivindex >= lastdivindex
			   then
			      while firstdivindex >= lastdivindex
			      do
				 closedivs = closedivs.."</div>"
				 firstdivindex = firstdivindex - 1
				 bdivii = string.gsub(bdivii, "depth", "Depth")
			      end
			   end
			   return string.format("%s%s%s%s%s%s%s%s",
						bdivi, ndivi, edivi, between,
						closedivs, bdivii, ndivii, edivii)
      end)
   end
   return str
end

local function clean_ekdscenes(str)
   str = string.gsub(str, "(<div.-)(%s[Dd]epth%=\"%d\")(.->)", "%1%3")
   used_ndivs = {}
   return str
end

--Prosimetrum
function process_prosimetrum(content)
    local processed = {}
    local block = {}
    local current_mode = nil -- can be "verse" or "prose"

    local function flush()
        if #block == 0 then return end
        if current_mode == "verse" then
            table.insert(processed, "\\begin{verse}\n" .. table.concat(block, "\n") .. "\n\\end{verse}")
        elseif current_mode == "prose" then
            table.insert(processed, "\\begin{justify}\n" .. table.concat(block, "\n") .. "\n\\end{justify}")
        end
        block = {}
    end

    for line in content:gmatch("[^\r\n]*\r?\n?") do
        local trimmed = line:gsub("^%s*(.-)%s*$", "%1")
        local is_blank = (trimmed == "")
        local is_verse = trimmed:match("\\\\[%+%?%>]?$") ~= nil

        if is_blank then
            if current_mode == "prose" then
                -- preserve blank lines as paragraph breaks in prose
                table.insert(block, "")
            end
            -- ignore blank lines in verse (don't insert anything)
        elseif is_verse then
            if current_mode ~= "verse" then
                flush()
                current_mode = "verse"
            end
            -- Keep verse lines exactly as-is, including endings like \\>, \\+, \\?
            table.insert(block, trimmed)
        else
            if current_mode ~= "prose" then
                flush()
                current_mode = "prose"
            end
            table.insert(block, trimmed)
        end
    end

    flush() -- flush the last block
    return table.concat(processed, "\n\n")
end

local loc = true

function ekddrama.setlocfalse()
   loc = false
end

local function locutor_totei(str, context)
    -- Check if any of the specified commands appear in the context
    local str, optionalArg = input:match("\\loc{(.-)}%[(.-)%]")
    if not str then
        -- If no optional argument is found, try to match without it
        str = input:match("\\loc{(.-)}")
    end
    
    local firstLoc = false
    for _, cmd in ipairs({"ekdact", "ekdscene", "stage"}) do
        if string.find(context, "\\" .. cmd) then
            firstLoc = true
            break
        end
    end

    -- Iterate over the castList to find the entry with the matching xmlid
    for _, entry in ipairs(castList) do
        if entry.xmlid == str then
            -- Construct the XML-like string using the role
            if firstLoc then
                return string.format('<sp who="#%s"><speaker>%s</speaker>', str, entry.role)
            else
                return string.format('</sp><sp who="#%s"><speaker>%s</speaker>', str, entry.role)
            end
        end
    end

-- Iterate over the castList to find the entry with the matching xmlid
    for _, entry in ipairs(castList) do
        if entry.xmlid == str then
            -- Construct the XML-like string using the role and optional argument
            if optionalArg then
                if firstLoc then
                    return string.format('<sp who="#%s"><stage>%s</stage><speaker>%s</speaker>', str, optionalArg, entry.role)
                else
                    return string.format('</sp><sp who="#%s"><stage>%s</stage><speaker>%s</speaker>', str, optionalArg, entry.role)
                end
            else
                if firstLoc then
                    return string.format('<sp who="#%s"><speaker>%s</speaker>', str, entry.role)
                else
                    return string.format('</sp><sp who="#%s"><speaker>%s</speaker>', str, entry.role)
                end
            end
        end
   end

    -- Return an empty string or a default message if no matching xmlid is found
    return ''
end



-- end drama





local function textotei(str)
   str = xml_entities(str)
   str = texpatttotei(str)
   str = footnote_totei(str)
   str = note_totei(str)
   str = remove_extra_anchors(str)
   str = app_totei(str)
   str = rdgGrp_totei(str)
   str = lem_rdg_totei(str)
   str = choice_totei(str)
   str = sic_corr_totei(str)
   str = abbr_expan_totei(str)
   str = orig_reg_totei(str)
   str = relocate_notes(str)
   str = stanzatotei(str)
   str = versetotei(str)
   str = envtotei(str)
   str = ekddivs_totei(str)
   str = section_totei(str)
   str = icitetotei(str)
   str = cmdtotei(str)
   str = texpatttotei(str)
   str = self_close_tags(str)
   str = partotei(str)
   str = ekdacts_totei(str)
   str = ekdscenes_totei(str)   
   if ekddivs
   then
      str = close_ekddivs_at_end(str)
      str = close_ekddivs_in_between(str)
      str = close_ekddivs_in_between(str)
      str = clean_ekddivs(str)
   else
      str = close_ndivs_at_end(str)
      str = close_ndivs_in_between(str)
      str = close_ndivs_in_between(str)
      str = clean_latexdivs(str)
   end
   if ekdacts
   then
      str = close_ekdacts_at_end(str)
      str = close_ekdacts_in_between(str)
      str = close_ekdacts_in_between(str)
      str = clean_ekdacts(str)
   end
   if ekdscenes
   then
      str = close_ekdscenes_at_end(str)
      str = close_ekdscenes_in_between(str)
      str = close_ekdscenes_in_between(str)
      str = clean_ekdscenes(str)
   end
   return str
end

local teifilename = tex.jobname.."-tei"

function ekddrama.setteifilename(str)
   teifilename = str
   return true
end

function ekddrama.openteistream()
   local f = io.open(teifilename.."_tmp.xml", "a+")
   f:write('<?xml version="1.0" encoding="utf-8"?>', "\n")
   f:write("<TEI xmlns=\"http://www.tei-c.org/ns/1.0\">", "\n")
   f:write("<teiHeader>", "\n")
   f:write("<fileDesc>", "\n")
   f:write("<titleStmt>", "\n")
   f:write("<title><!-- Title --></title>", "\n")
   f:write("<respStmt>", "\n")
   f:write("<resp><!-- Edited by --></resp>", "\n")
   f:write("<name><!-- Name --></name>", "\n")
   f:write("</respStmt>", "\n")
   f:write("</titleStmt>", "\n")
   f:write("<publicationStmt>", "\n")
   f:write("<distributor><!-- Distributor name  --></distributor>", "\n")
   f:write("</publicationStmt>", "\n")
   f:write("<sourceDesc>", "\n")
   if next(listWit) == nil and next(listPerson) == nil
   then
      f:write("<p>No source, born digital</p>", "\n")
   else
      if next(listWit) ~= nil
      then
	 f:write("<listWit>", "\n")
	 for i = 1,#listWit do
	    f:write('<witness xml:id=\"', listWit[i].xmlid, "\">", "\n")
	    f:write('<abbr type="siglum">', textotei(listWit[i].abbr), "</abbr>", "\n")
	    f:write(textotei(listWit[i].detailsDesc), "\n")
	    f:write("<msDesc>", "\n")
	    if listWit[i].msIdentifier.settlement == ""
	       and listWit[i].msIdentifier.institution == ""
	       and listWit[i].msIdentifier.repository == ""
	       and listWit[i].msIdentifier.collection == ""
	       and listWit[i].msIdentifier.idno == ""
	       and listWit[i].msIdentifier.msName == ""
	    then
	       f:write("<msIdentifier/>", "\n")
	    else
	       f:write("<msIdentifier>", "\n")
	       if listWit[i].msIdentifier.settlement ~= "" then
		  f:write("<settlement>", textotei(listWit[i].msIdentifier.settlement), "</settlement>", "\n")
	 else end
	       if listWit[i].msIdentifier.institution ~= "" then
		  f:write("<institution>", textotei(listWit[i].msIdentifier.institution), "</institution>", "\n")
	 else end
	       if listWit[i].msIdentifier.repository ~= "" then
		  f:write("<repository>", textotei(listWit[i].msIdentifier.repository), "</repository>", "\n")
	 else end
	       if listWit[i].msIdentifier.collection ~= "" then
		  f:write("<collection>", textotei(listWit[i].msIdentifier.collection), "</collection>", "\n")
	 else end
	       if listWit[i].msIdentifier.idno ~= "" then
		  f:write("<idno>", textotei(listWit[i].msIdentifier.idno), "</idno>", "\n")
	 else end
	       if listWit[i].msIdentifier.msName ~= "" then
		  f:write("<msName>", textotei(listWit[i].msIdentifier.msName), "</msName>", "\n")
	 else end
	       f:write("</msIdentifier>", "\n")
	    end
	    if listWit[i].handDesc ~= nil then
	       f:write("<physDesc>", "\n")
	       f:write("<handDesc hands=\"", #listWit[i].handDesc, "\">", "\n")
	       local j = 1
	       while listWit[i].handDesc[j]
	       do
		  f:write("<handNote xml:id=\"", listWit[i].handDesc[j].xmlid, "\">", "\n")
		  f:write('<abbr type="siglum">', textotei(listWit[i].handDesc[j].abbr), "</abbr>", "\n")
		  f:write("<p>", textotei(listWit[i].handDesc[j].detailsDesc), "</p>", "\n")
		  f:write("</handNote>", "\n")
		  j = j + 1
	       end
	       f:write("</handDesc>", "\n")
	       f:write("</physDesc>", "\n")
	    else end
	    if listWit[i].msContents ~= nil then
	       f:write("<msContents>", "\n")
	       f:write("<msItemStruct>", "\n")
	       f:write("<locus>", textotei(listWit[i].msContents.msItemStruct.locus), "</locus>", "\n")
	       f:write("</msItemStruct>", "\n")
	       f:write("</msContents>", "\n")
	    end
	    if listWit[i].history ~= nil then
	       f:write("<history>", "\n")
	       f:write("<origin>", "\n")
	       f:write("<origDate>", textotei(listWit[i].history.origin.origDate), "</origDate>", "\n")
	       f:write("</origin>", "\n")
	       f:write("</history>", "\n")
	    end
	    f:write("</msDesc>", "\n")
	    f:write("</witness>", "\n")
	 end
	 f:write("</listWit>", "\n")
      end
      if next(listPerson) ~= nil
      then
	 f:write("<listPerson xml:id=\"scholars\">", "\n")
	 for i = 1,#listPerson do
	    f:write('<person xml:id=\"', listPerson[i].xmlid, "\">", "\n")
	    f:write('<persName>', "\n")
	    f:write('<abbr type="siglum">', textotei(listPerson[i].abbr), "</abbr>", "\n")
	    if listPerson[i].persName.name ~= nil
	    then
	       f:write(textotei(listPerson[i].persName.name))
	    else
	       if listPerson[i].persName.forename ~= ""
	       then
		  f:write("<forename>", textotei(listPerson[i].persName.forename), "</forename>", "\n")
	       else
		  f:write("<forename><!-- forename --></forename>", "\n")
	       end
	       if textotei(listPerson[i].persName.surname) ~= ""
	       then
		  f:write("<surname>", textotei(listPerson[i].persName.surname), "</surname>", "\n")
	       else
		  f:write("<surname><!-- surname --></surname>", "\n")
	       end
	       if textotei(listPerson[i].persName.addName) ~= ""
	       then
		  f:write("<addName>", textotei(listPerson[i].persName.addName), "</addName>", "\n")
	       end
	    end
	    if listPerson[i].note ~= ""
	    then
	       f:write("<note>", textotei(listPerson[i].note), "</note>", "\n")
	    end
	    f:write('</persName>', "\n")
	    f:write('</person>', "\n")
	 end
	 f:write("</listPerson>", "\n")
      end
   end
   f:write("</sourceDesc>", "\n")
   f:write("</fileDesc>", "\n")
   f:write("<encodingDesc>", "\n")
   f:write('<variantEncoding method="parallel-segmentation" location="internal"/>', "\n")
   f:write("</encodingDesc>", "\n")
   f:write("</teiHeader>", "\n")
   f:write("<text>", "\n")
   f:write("<front>", "\n")
	if next(castList) == nil then
		f:write("<p>No cast list present</p>", "\n")
	else
		f:write("<castList>", "\n")
		for i = 1, #castList do
			f:write("<castItem>", "\n")
                f:write('<role xml:id="', castList[i].xmlid, '">', textotei(castList[i].role), "</role>", "\n")
			if castList[i].roleDesc ~= "" then
				f:write("<roleDesc>", textotei(castList[i].roleDesc), "</roleDesc>", "\n")
			end
			if castList[i].actor ~= "" then
				f:write("<actor>", textotei(castList[i].actor), "</actor>", "\n")
			end
			f:write("</castItem>", "\n")
		end
		f:write("</castList>", "\n")
	end
        if next(set) == nil then
		f:write("<p>No set defined</p>", "\n")
	else
		f:write("<set><p>", "\n")
		for i = 1, #set do
		end
		f:write("</p></set>", "\n")
	end
	f:write("</front>", "\n")
   f:write("<body>", "\n")
   f:close()
   return true
end

local tidy = nil

local function cleanup_tei()
   local f = assert(io.open(teifilename.."_tmp.xml", "r"))
   t = f:read("*a")
   t = string.gsub(t, "%<p%>%s?%</p%>", "")
   t = string.gsub(t, "^\n", "")
   f:close()
   local fw = assert(io.open(teifilename.."_tmp.xml", "w"))
   fw:write(t)
   fw:close()
   return true
end

function ekddrama.closeteistream(opt)
   local f = io.open(teifilename.."_tmp.xml", "a+")
   f:write("\n", "</body>", "\n")
   if xmlbibresource ~= nil then
      bibf = assert(io.open(xmlbibresource, "r"))
      t = bibf:read("*a")
      t = string.gsub(t, "%s+corresp%=%b\"\"", "")
      t = string.gsub(t, "\n\n", "\n")
      f:write("<back>", "\n")
      f:write("<listBibl>", "\n")
      for i in string.gmatch(t, "<biblStruct.->.-</biblStruct>")
      do
	 f:write(i, "\n")
      end
      f:write("</listBibl>", "\n")
      f:write("</back>", "\n")
      bibf:close()
   else
   end
   f:write("</text>", "\n")
   f:write("</TEI>", "\n")
   f:close()
   cleanup_tei()
   os.remove(teifilename..".xml")
   os.rename(teifilename.."_tmp.xml", teifilename..".xml")
   if opt == "tidy" then
      os.execute("tidy -qmi -xml --output-xml yes "..teifilename..".xml")
   else
   end
   return true
end

function ekddrama.exporttei(str)
   local f = io.open(teifilename.."_tmp.xml", "a+")
   -- f:write("\n<p>")
   str = textotei(str)
   f:write(str)
   f:close()
   return true
end
-- end totei functions

-- begin basic TeX Conspectus siglorum
function ekddrama.basic_cs(msid)
   local indexwit = getindex(msid, listWit)
   siglum = listWit[indexwit].abbr
   -- if listWit[indexwit].detailsDesc == ""
   -- then
   -- name = listWit[indexwit].msIdentifier.msName
   -- else
   --    name = listWit[indexwit].msIdentifier.msName
   -- 	 .."\\thinspace\\newline\\bgroup\\footnotesize{}"..
   -- 	 listWit[indexwit].detailsDesc
   -- 	 .."\\egroup{}"
   -- end
   name = listWit[indexwit].detailsDesc
   if listWit[indexwit].history ~= nil
      and
      listWit[indexwit].history.origin ~= nil
   then
      date = listWit[indexwit].history.origin.origDate
   else
      date = ""
   end
   if listWit[indexwit].msContents ~= nil
      and
      listWit[indexwit].msContents.msItemStruct ~= nil
   then
      locus = listWit[indexwit].msContents.msItemStruct.locus
   else
      locus = ""
   end
   return siglum.."&"..name.." "..locus.."&"..date
end
-- end basic TeX Conspectus siglorum

-- begin Cast List
function ekddrama.basic_cl(cid)
	local indexcast = getindex(cid, castList)
	local role = castList[indexcast].role or ""
	local roleDesc = castList[indexcast].roleDesc or ""
	local actor = castList[indexcast].actor or ""
	return role .. " & " .. roleDesc .. " & " .. actor .. " \\\\"
end

function ekddrama.cast_table()
	local output = {}
	for i = 1, #castList do
		local entry = castList[i]
		local role = entry.role or ""
		local roleDesc = entry.roleDesc or ""
		local actor = entry.actor or ""
		table.insert(output, role .. " & " .. roleDesc .. " & " .. actor .. " \\\\")
	end
	return table.concat(output, "\n")
end
-- end Cast List

function ekddrama.removesp(str)
   str = gsub(str, cmd * cmdargs * spcenc^-1, "%1%2")
   return str
end

function ekddrama.closestream()
   os.remove(tex.jobname..".ekd")
   os.rename(tex.jobname.."_tmp.ekd", tex.jobname..".ekd")
   return true
end

local cur_abs_pg = 0
local ekd_abs_pg = 0
local pg_i = nil
local pg_ii = nil
local prevcol = nil
local curcol = "x"

local check_resetlineno = {}

function ekddrama.update_abspg(n) -- not used
   cur_abs_pg = n
   return true
end

function ekddrama.storeabspg(n, pg)
   if tonumber(n) > tonumber(cur_abs_pg)
   then
      ekd_abs_pg = ekd_abs_pg + 1
   end
   cur_abs_pg = n
   n = ekd_abs_pg
   if pg == "pg_i" then
      pg_i = n
   elseif pg == "pg_ii" then
      pg_ii = n
      table.insert(check_resetlineno, curcol.."-"..pg_ii)
   end
   return true
end

function ekddrama.getekdabspg()
   return ekd_abs_pg
end

function ekddrama.checkresetlineno()
   if isfound(check_resetlineno, curcol.."-"..pg_i)
   then
      return ""
   else
      return "\\resetlinenumber"
   end
end

--
-- Build environments to be aligned
--

local cur_alignment = "-"
local cur_alignment_patt = "%-"
local cur_alignment_cnt = 1

local newalignment = false
function ekddrama.newalignment(str)
   if str == "set"
   then
      newalignment = true
      cur_alignment = "-"..cur_alignment_cnt.."-"
      cur_alignment_patt = "%-"..cur_alignment_cnt.."%-"
      cur_alignment_cnt = cur_alignment_cnt + 1
   elseif str == "reset"
   then
      newalignment = false
      cur_alignment = "-"
      cur_alignment_patt = "%-"
   end
   return true
end

local aligned_texts = {}
local texts_w_apparatus = {}
local coldata_totei = {}

local function sanitize_envdata(str)  -- look for a better way to achieve this
   str = string.gsub(str, "(%a+)%s+(%b[])", "%1%2")
   str = string.gsub(str, "(%a+)(%b[])%s+", "%1%2")
   str = string.gsub(str, "%s+(%a+)(%b[])", "%1%2")
   str = gsub(str, lpeg.Cs(letters^1)
		 * spcenc^-1
		 * -bsqbrackets
		 * lpeg.Cs(";"), "%1[]%2")
   str = string.gsub(str, "%s+(%a+)(%b[])", "%1%2")
   return str
end

function ekddrama.mkenvdata(str, opt)
   if not string.find(str, "%;", -1) then str = str .. ";" else end
   --   str = str ..";"
   --   str = string.gsub(str, "%s+", "")
   local fieldstart = 1
   local col = 0
   if opt == "texts" then
      str = sanitize_envdata(str)
      repeat
	 local _s, nexti = string.find(str, "%b[]%s-%;", fieldstart)
	 local namediv = string.gsub(string.sub(str, fieldstart, nexti-1), "(%a+)%s-(%b[])", "%1")
	 local attr = string.gsub(string.sub(str, fieldstart, nexti-1), "(%a+)%s-(%b[])", "%2")
	 attr = string.sub(attr, 2, -2)
	 if forbid_xmlid
	 then
	    attr = string.gsub(attr, "xml:id", "n") -- xml:id is not allowed here
	 else
	 end
	 table.insert(aligned_texts, { text = namediv,
				       attribute = attr,
				       column = col })
	 table.insert(coldata_totei, { environment = namediv,
				       data = {} })
	 col = col + 1
	 fieldstart = nexti + 1
      until fieldstart > string.len(str)
      return aligned_texts
   elseif opt == "apparatus" then
      repeat
	 local nexti = string.find(str, "%;", fieldstart)
	 table.insert(texts_w_apparatus, string.sub(str, fieldstart, nexti-1))
	 fieldstart = nexti +1
      until fieldstart > string.len(str)
      return texts_w_apparatus
   end
end

-- Reminder: the following two variables are already set above
-- local prevcol = nil
-- local curcol = "x"

function ekddrama.storecurcol(n)
      curcol = n
   return true
end

function ekddrama.flushcolnums()
   prevcol = nil
   curcol = "x"
   return true
end

function ekddrama.flushenvdata()
   aligned_texts = {}
   texts_w_apparatus = {}
   coldata_totei = {}
   return true
end

function ekddrama.storecoldata(nthcol, chunk)
   local tindex = tonumber(nthcol) + 1
   table.insert(coldata_totei[tindex].data, chunk)
   return true
end

local environment_div = {}

local function build_envdiv(str)
   if not environment_div[str]
   then
      environment_div[str] = 1
   else
      environment_div[str] = environment_div[str] + 1
   end
   local div = "div-"..str.."_"..environment_div[str]
   if xmlidfound(div)
   then
      tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
		   ..div..
		   "\" already exists as an xml:id. "
		   ..
		   "ekddrama has generated some random id.}}")
      return "div-"..math.random(1000,9999)
   elseif not checkxmlid(div)
   then
      tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
      	 ..div..
      	 "\" is not a valid xml:id. \\MessageBreak "
      	 ..
      	 "Please pick another id.}}")
   else
      table.insert(xmlids, {xmlid = div})
      table.sort(xmlids, function(a ,b) return(#a.xmlid > #b.xmlid) end)
      return div
   end
end

function ekddrama.mkenv()
   local environments = {}
   for i = 1,#aligned_texts
   do
      if isfound(texts_w_apparatus, aligned_texts[i].text)
      then
	 table.insert(environments, "\\NewDocumentEnvironment{".. aligned_texts[i].text.."}{+b}"
		      .."{\\begin{nthcolumn}{".. aligned_texts[i].column.."}"
		      .."\\csname if@pkg@breakable\\endcsname\\raggedbottom\\fi"
		      .."\\par"
		      .."\\ekddramaColStart"
		      .."\\ekddramaOn#1"
		      .."}{\\ekddramaOff"
		      .."\\ekddramaColStop"
		      .."\\end{nthcolumn}"
		      .."\\csname iftei@export\\endcsname\\luadirect{ekddrama.storecoldata("
		      .. aligned_texts[i].column
		      ..", \\luastringN{\\par#1\\par})}\\fi"
		      .."}")
	 table.insert(environments, "\\NewDocumentEnvironment{".. aligned_texts[i].text.."*}{+b}"
		      .."{\\begin{nthcolumn*}{".. aligned_texts[i].column.."}[]"
		      .."\\par"
		      .."\\ekddramaColStart"
		      .."\\ekddramaOn#1"
		      .."}{\\ekddramaOff"
		      .."\\ekddramaColStop"
		      .."\\end{nthcolumn*}"
		      .."\\csname iftei@export\\endcsname\\luadirect{ekddrama.storecoldata("
		      .. aligned_texts[i].column
		      ..", \\luastringN{\\par#1\\par})}\\fi"
		      .."}")
      else
	 table.insert(environments, "\\NewDocumentEnvironment{".. aligned_texts[i].text.."}{+b}"
		      .."{\\begin{nthcolumn}{".. aligned_texts[i].column.."}"
		      .."\\par"
		      .."#1"
		      .."}{\\end{nthcolumn}"
		      .."\\csname iftei@export\\endcsname\\luadirect{ekddrama.storecoldata("
		      .. aligned_texts[i].column
		      ..", \\luastringN{\\par#1\\par})}\\fi"
		      .."}")
	 table.insert(environments, "\\NewDocumentEnvironment{".. aligned_texts[i].text.."*}{+b}"
		      .."{\\begin{nthcolumn*}{"..aligned_texts[i].column.."}[]"
		      .."\\par"
		      .."#1"
		      .."}{"
		      .."\\end{nthcolumn*}"
		      .."\\csname iftei@export\\endcsname\\luadirect{ekddrama.storecoldata("
		      .. aligned_texts[i].column
		      ..", \\luastringN{\\par#1\\par})}\\fi"
		      .."}")
      end
      forbid_xmlid = false
      if aligned_texts[i].attribute ~= ""
      then
	 ekddrama.newenvtotag(aligned_texts[i].text, "div",
			     "xml:id=\""
				..build_envdiv(aligned_texts[i].text)
				.."\" "
				..aligned_texts[i].attribute)
      else
	 ekddrama.newenvtotag(aligned_texts[i].text, "div",
			     "xml:id=\""
				..build_envdiv(aligned_texts[i].text)
				.."\"")
      end
      forbid_xmlid = true
   end
   str = table.concat(environments)
   return str
end

function ekddrama.export_coldata_totei()
   for i = 1,#coldata_totei
   do
      ekddrama.exporttei("\\begin{".. coldata_totei[i].environment .."}"
			   .. table.concat(coldata_totei[i].data)
			.. "\\end{".. coldata_totei[i].environment .."}")
   end
end

-- maxlines
--

local localmaxlines = nil

function ekddrama.resetlocalmaxlines()
   localmaxlines = nil
   return "\\setcounter{ekd@locallnperpage}{0}"
end

function ekddrama.setlocalmaxlines(n)
   n = tonumber(n)
   if math.type(n) == "integer"
   then
      localmaxlines = n
   end
   return "\\setcounter{ekd@locallnperpage}{1}"
end

function ekddrama.addtomaxlines(ni, nii)
   ni = tonumber(ni)
   nii = tonumber(nii)
   if math.type(ni) == "integer" and math.type(nii) == "integer"
   then
      localmaxlines = ni + nii
   end
   return "\\setcounter{ekd@locallnperpage}{1}"
end

function ekddrama.getlocalmaxlines()
   if localmaxlines
   then
      return localmaxlines
   end
end

-- apparatus height
--
local appheightchanged = false

function ekddrama.changeappheight()
   appheightchanged = true
end

function ekddrama.setheightandprintapparatus()
   if appheightchanged == true
   then
      appheightchanged = false
      return "\\csname ekd@insert@fitapparatus@tmpheight\\endcsname"
   else
      return "\\csname ekd@insert@fitapparatus\\endcsname"
   end
end

-- handle multiple layers in apparatuses
--
local apparatuses = {}
local bagunits = {}
local glimit = nil
local gunits = 0

function ekddrama.newapparatus(teitype,
			      appdir,
			      apprule,
			      appdelim,
			      appsep,
			      appsubsep,
			      appbhook,
			      appehook,
			      applimit,
			      applang,
			      appnotelang)
   if isintable(apparatuses, teitype)
   then
      tex.print("\\unexpanded{\\PackageWarning{ekddrama}{\""
		   ..teitype..
		   "\" already exists.}}")
   else
      table.insert(apparatuses, {a = teitype,
				 direction = appdir,
				 rule = apprule,
				 delim = appdelim,
				 sep = appsep,
				 subsep = appsubsep,
				 bhook = appbhook,
				 ehook = appehook,
				 limit = applimit,
				 lang = applang,
				 notelang = appnotelang})
   end
   bagunits[teitype] = 1
   return true
end

function ekddrama.getapplang(teitype)
   i = get_a_index(teitype, apparatuses)
   if apparatuses[i].lang ~= ""
   then
      return apparatuses[i].lang
   else
      return "\\languagename"
   end
end

function ekddrama.getappnotelang(teitype)
   i = get_a_index(teitype, apparatuses)
   if apparatuses[i].notelang ~= ""
   then
      return apparatuses[i].notelang
   else
      return "\\languagename"
   end
end

function ekddrama.getappdelim(str)
   for i = 1,#apparatuses
   do
      if apparatuses[i].a == str then
	 delimfound = apparatuses[i].delim
	 break
      end
   end
   return delimfound
end

function ekddrama.get_bagunits(teitype)
   return bagunits[teitype]
end

local function getapplimit(teitype)
   for i = 1,#apparatuses
   do
      if apparatuses[i].a == teitype then
	 limitfound = apparatuses[i].limit
	 break
      end
   end
   if tonumber(limitfound) ~= nil
   then
      if tonumber(limitfound) < 10
      then
	 return 0
      else
	 return limitfound
      end
   else
      return 0
   end
end

function ekddrama.limit_bagunits(teitype)
   local limit = tonumber(getapplimit(teitype))
   if glimit then
      glimit = tonumber(glimit)
      gunits = tonumber(gunits)
      if glimit >= 10 and gunits >= glimit
      then
	 bagunits[teitype] = 2
	 gunits = 0
	 return "\\pagebreak"
      else
	 if limit >= 10 and bagunits[teitype] >= limit
	 then
	    bagunits[teitype] = 2
	    gunits = 0
	    return "\\pagebreak"
	 else
	    return ""
	 end
      end
   else
      if limit >= 10 and bagunits[teitype] >= limit
      then
	 bagunits[teitype] = 2
	 gunits = 1
	 return "\\pagebreak"
      else
	 return ""
      end
   end
end

function ekddrama.addto_bagunits(teitype, n)
   n = tonumber(n)
   if glimit then gunits = gunits - n end
   if tonumber(getapplimit(teitype)) ~= 0
   then
      bagunits[teitype] = bagunits[teitype] - n
   end
end

function ekddrama.increment_bagunits(teitype)
   if glimit then gunits = gunits + 1 end
   bagunits[teitype] = (bagunits[teitype] or 0) + 1
end

function ekddrama.setglimit(n)
   if math.tointeger(n)
   then
      glimit = math.tointeger(math.abs(n))
   else
      glimit = nil
   end
end

local function reset_bagunits()
   if glimit then gunits = 0 end
   for i = 1,#apparatuses
   do
      bagunits[apparatuses[i].a] = 1
   end
end

function ekddrama.appin(str, teitype)
   local f = io.open(tex.jobname.."_tmp.ekd", "a+")
   if next(apparatuses) == nil
   then
      f:write("<", ekd_abs_pg, cur_alignment, curcol, "-0>", str, "</",
	      ekd_abs_pg, cur_alignment, curcol, "-0>\n")
   else
      for i = 1,#apparatuses
      do
	 if apparatuses[i].a == teitype then
	    appno = i
	    break
	 end
      end
      f:write("<", ekd_abs_pg, cur_alignment, curcol, "-",
	      appno, ">", str, "</", ekd_abs_pg, cur_alignment, curcol, "-", appno, ">\n")
   end
   f:close()
   return true
end

function ekddrama.appout()
   local file = io.open(tex.jobname..".ekd", "r")
   if file ~= nil then io.close(file)
      f = assert(io.open(tex.jobname..".ekd", "r"))
      t = f:read("*a")
      local output = {}
      if next(apparatuses) == nil then
	 -- table.insert(output, "BEGIN")
	 table.insert(output, "\\csname ekd@default@rule\\endcsname\\NLS")
	 table.insert(output, "\\csname ekd@begin@apparatus\\endcsname\\ignorespaces")
--	 table.insert(output, "\\noindent ")
	 for i in string.gmatch(t,
				"<"..ekd_abs_pg
				   ..cur_alignment_patt
				   ..curcol.."%-0>.-</"
				   ..ekd_abs_pg
				   ..cur_alignment_patt
				   ..curcol.."%-0>")
	 do
	    table.insert(output, i)
	 end
	 -- table.insert(output, "END")
      else
	 local appinserted = false
	 local n = 1
	 while apparatuses[n]
	 do
	    if string.match(t, "<"..ekd_abs_pg
			       ..cur_alignment_patt
			       ..curcol.."%-"..n..">.-</"
			       ..ekd_abs_pg
			       ..cur_alignment_patt
			       ..curcol.."%-"..n..">")
	    then
	       -- table.insert(output, "BEGIN")
	       table.insert(output, "\\bgroup{}")
	       if apparatuses[n].direction == "LR"
	       then
		  table.insert(output, "\\pardir TLT\\leavevmode\\textdir TLT{}")
	       elseif apparatuses[n].direction == "RL"
	       then
		  table.insert(output, "\\pardir TRT\\leavevmode\\textdir TRT{}")
	       end
	       if apparatuses[n].rule == "none"
	       then
		  if n > 1
		  then
		     if appinserted
		     then
			table.insert(output, "\\NLS{}")
		     end
		  else
		     table.insert(output, "\\noindent ")
		  end
	       elseif apparatuses[n].rule ~= ""
	       then
		  if n > 1
		  then
		     if appinserted
		     then
			table.insert(output, "\\NLS{}" .. apparatuses[n].rule .. "\\NLS{}")
		     else
			table.insert(output, apparatuses[n].rule .. "\\NLS{}")
		     end
		  else
--		     table.insert(output, "\\noindent ")
		     table.insert(output, apparatuses[n].rule .. "\\NLS{}")
		  end
	       else
		  if n > 1
		  then
		     if appinserted
		     then
			table.insert(output, "\\NLS\\csname ekd@default@rule\\endcsname\\NLS{}")
		     else
			table.insert(output, "\\csname ekd@default@rule\\endcsname\\NLS{}")
		     end
		  else
--		     table.insert(output, "\\noindent ")
		     table.insert(output, "\\csname ekd@default@rule\\endcsname\\NLS{}")
		  end
	       end
	       if apparatuses[n].sep ~= ""
	       then
		  table.insert(output, "\\def\\ekdsep{" .. apparatuses[n].sep .. "}")
	       else
	       end
	       if apparatuses[n].subsep ~= ""
	       then
		  table.insert(output, "\\def\\ekdsubsep{" .. apparatuses[n].subsep .. "}")
	       end
	       if apparatuses[n].bhook ~= ""
	       then
		  table.insert(output, apparatuses[n].bhook)
	       else
		  table.insert(output, "\\relax")
	       end
	       for i in string.gmatch(t,
				      "<"..ekd_abs_pg
					 ..cur_alignment_patt
					 ..curcol.."%-"..n..">.-</"
					 ..ekd_abs_pg
					 ..cur_alignment_patt
					 ..curcol.."%-"..n..">")
	       do
		  table.insert(output, i)
		  appinserted = true
	       end
	       if apparatuses[n].ehook ~= ""
	       then
		  table.insert(output, apparatuses[n].ehook)
	       else
	       end
	       table.insert(output, "\\egroup{}")
	       -- table.insert(output, "END")
	    end
	    n = n + 1
	 end
      end
      f:close()
      str = table.concat(output)
      str = string.gsub(str, "</"..ekd_abs_pg..cur_alignment_patt..curcol.."%-[0-9]>", "")
      str = string.gsub(str, "<"..ekd_abs_pg..cur_alignment_patt..curcol.."%-[0-9]>", " ")
      return str
   else
   end
end

function ekddrama.appin_out(str, nl)
   local f = io.open(tex.jobname.."_tmp.ekd", "a+")
   if nl == "yes" then
      f:write(str, "\n")
   else
      f:write(str)
   end
   f:close()
   return true
end

local curcol_curabspg = {}

function ekddrama.testapparatus()
   if isfound(curcol_curabspg, curcol.."-"..ekd_abs_pg)
   then
      if newalignment
      then
	 if next(apparatuses) ~= nil then
	    reset_bagunits()
	 end
	 newalignment = false
	 return "\\booltrue{do@app}"
      else
	 return "\\boolfalse{do@app}"
      end
   else
      table.insert(curcol_curabspg, curcol.."-"..ekd_abs_pg)
      if next(apparatuses) ~= nil then
	 reset_bagunits()
      end
      newalignment = false
      return "\\booltrue{do@app}"
   end
end

local function get_ln_prefix(x, y)
   for index = 1, string.len(x)
   do
      if string.sub(x, index, index) ~= string.sub(y, index, index)
      then
	 return string.sub(x, 1, index - 1)
      end
   end
end

function ekddrama.numrange(x, y)
  xstr = tostring(x)
  ystr = tostring(y)
  if x == y -- which will never apply
  then
     return "\\LRnum{" .. xstr .. "}"
  elseif string.len(xstr) ~= string.len(ystr)
  then
     return "\\LRnum{" .. xstr .. "}--\\LRnum{" .. ystr .. "}"
  else
    common = get_ln_prefix(xstr, ystr)
    if string.len(common) == 0
    then
       return "\\LRnum{" .. xstr .. "}--\\LRnum{" .. ystr .. "}"
    elseif string.sub(xstr, -2, -2) == "1"
    then
       return "\\LRnum{"
	  .. string.sub(common, 1, -2)
	  .. string.sub(xstr, string.len(common), -1)
	  .. "}--\\LRnum{"
	  .. string.sub(ystr, string.len(common), -1)
	  .. "}"
    else
       return "\\LRnum{"
	  .. string.sub(common, 1, -1)
	  .. string.sub(xstr, string.len(common) + 1, -1)
	  .. "}--\\LRnum{"
	  .. string.sub(ystr, string.len(common) + 1, -1)
	  .. "}"
    end
  end
end

local lnlabs = {}
local lnlab_salt = 0
local current_lnlab = nil
local prev_lnlab = nil
local prev_prev_lnlab = nil
local indexed_labs = {}
local notelabs = {}
local current_notelab = nil
local prev_notelab = nil
local current_lemma = nil
local salt = 0

local function mdvisintable(table, value)
   for _, v in pairs(table) do
      if v == value then return true end
   end
   return false
end

function ekddrama.dolnlab(str, indexlab)
   if prev_lnlab ~= nil then prev_prev_lnlab = prev_lnlab end
   prev_lnlab = current_lnlab
   current_lemma = str
   i = md5.sumhexa(str)
   if not mdvisintable(lnlabs, i) then
      table.insert(lnlabs, i)
      if indexlab ~= nil
      then
	 indexed_labs[indexlab] = i
      end
   else
      i = i..salt
      table.insert(lnlabs, i)
      if indexlab ~= nil
      then
	 indexed_labs[indexlab] = i
      end
      salt = salt + 1
   end
   current_lnlab = i
   return true
end

function ekddrama.getlnlab()
   return current_lnlab
end

function ekddrama.getprevlnlab()
   return prev_lnlab
end

function ekddrama.getprevprevlnlab()
   return prev_prev_lnlab
end

function ekddrama.getindexedlab(str)
   if indexed_labs[str] == nil
   then return "\\csname ekd@wrong@ilabel\\endcsname"
   else
      return "\\linelabel{" .. indexed_labs[str] .. "-e}"
   end
end

function ekddrama.setnotelab(str)
   current_notelab = str
   if isfound(notelabs, current_notelab)
   then
      return ""
   else
      table.insert(notelabs, current_notelab)
      return "\\linelabel{" .. current_notelab .. "}"
   end
end

function ekddrama.getnotelab()
   return current_notelab
end

function ekddrama.setprevnotelab(str)
   prev_notelab = str
   return true
end

function ekddrama.getprevnotelab()
   return prev_notelab
end

local cmdstorm = lpeg.P(lpeg.P("note")
			+ lpeg.P("milestone")
			+ lpeg.P("linelabel")
			+ lpeg.P("ilabel")
			+ lpeg.P("index"))

local function remove_from_app(str)
   str = gsub(str, dblbkslash * cmdstorm * cmdargs, "")
   return str
end

function ekddrama.mdvappend(str, teitype, ilabel)
   if current_lemma == ""
   then
      current_lemma = "\\ekdunspace"
   end
   local labelbegin = "\\linelabel{" .. current_lnlab .. "-b}\\wordboundary{}"
   local labelend = "\\linelabel{" .. current_lnlab .. "-e}"
   if ilabel ~= nil
   then
      labelend = ""
   end
   if teitype == nil
   then
      return labelbegin
	 ..
	 current_lemma
	 ..
	 labelend
	 ..
	 "\\csname append@app\\endcsname{"
	 .. remove_from_app(str) .. "}"
   else
      return labelbegin
	 ..
	 current_lemma
	 ..
	 labelend
	 ..
	 "\\csname append@app\\endcsname" .. "[" .. teitype ..  "]{"
	 .. remove_from_app(str) .. "}"
   end
end