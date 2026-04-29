# Examen de synthèse

## Les fichiers .tex

Pour une première réflexion sur l'aspect formel du texte, j'ai utilisé des textes fictifs dans deux des trois cas. En effet, en ce qui concerne verse.tex, le texte codé reprend le début des _Plaideurs_ de Jean Racine (1669), que j’ai fait suivre d’un passage de _Lorem ipsum_. Le fichier prose.tex présente le premier acte du _Monsieur de Pourceaugnac_ de Molière (1670). Et le dernier, prosimetrum.tex, présente le texte de la scène dix du _Comte de Rocquefœuilles ou le Docteur extravagant_ (1669) de Denis Clerselier de Nanteuil.

## Déclaration du paquet et choix formelle

Plutôt que de proposer l'intégration d'un modèle directement dans le préambule d'un fichier à compiler avec ekdosis, je pense qu'il serait plus simple de créer un paquet extension capable de gérer tous les cas spécifiques au théâtre.

Dans le préambule du document en cours de rédaction, il suffit d'insérer la commande `\usepackage{ekddrama}`à compléter par l'option correspondant à notre texte ; par exemple, pour une pièce de théâtre en vers, il suffit d'ajouter cette définition pour `speech`: `\usepackage[speech=verse]{ekddrama}`. De même, les options disponibles sont `speech=prose` ou `speech=prosimetrum`. 


Le choix de ces options est indiqué comme clés de définition du paquet, comme suit :

```latex
\newif\if@pkg@poetry@verse
\newif\if@pkg@prose
\newif\if@pkg@prosimetrum
\ekvdefinekeys{ekddrama}{
choice speech = {prose = {\@pkg@prosetrue},
    verse = {\@pkg@prosefalse\@pkg@poetry@versetrue},
    prosimetrum = {\@pkg@prosefalse\@pkg@prosimetrumtrue}},
  initial speech = prose,
  unknown-choice speech = {\PackageError{ekddrama}{Unknown speech=#1}{`speech' must be either `prose', `verse' or 'prosimetrum'.}}
}
```
Défini par la suite comme un texte justifié aux deux marges dans le cas de la prose et comme un texte respectant les règles de la poésie, dans ce cas précis.

```latex 
\if@pkg@prose
   \newenvironment{speech}{
    \begin{justify}
    }{
    \end{justify}}
\fi
\if@pkg@poetry@verse
\newenvironment{speech}{
\begin{verse}
}{
\end{verse}}
\fi

%\begin{luacode*}
%\end{luacode*}


\if@pkg@prosimetrum
    \newenvironment{speech}{
    \luadirect{process_prosimetrum(content)}
}
\fi
```

La gestion du prosimetrum est plus complexe, car il doit déterminer automatiquement s'il s'agit d'un vers ou de prose. Le document `ekddrama.sty` fait référence à `ekddrama.lua`. Dans ce cas, il faut tenir compte du fait que la fin des vers est délimitée par des marqueurs (\\, \\+, \\>, \\?); ainsi, en reconnaissant les chaînes de caractères qui se terminent par l'une de ces séquences de marqueurs, le système comprend qu'il s'agit d'un vers, sinon il s'agit de prose. Le texte ainsi reconnu est formaté selon ses besoins.

```lua
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
```

Au stade actuel du développement du paquet, la reconnaissance et le traitement formel du texte posent encore quelques difficultés, notamment en ce qui concerne la numérotation — un sujet qui mérite d'être abordé à part — et surtout la sortie `XML-TEI`.

## La liste des personnages

Une caractéristique propre au texte théâtral est la liste des personnages, que j'ai décidé, pour des raisons pratiques, de calquer sur le _Conspectus siglorum_ d'Alessi. Dans le fichier `ekddrama.sty`, j'ai défini que ma liste des personnages, DeclareCast, doit comporter trois éléments obligatoires, à savoir un identifiant, le rôle et la description du rôle, ainsi qu'une valeur facultative, l'acteur ou l'actrice qui a interprété le rôle.

```latex
\ekvdefinekeys{ekd@role}{%
  store roleDesc = \roleDesc@value,
  store actor = \actor@value
}

\NewDocumentCommand{\DeclareCast}{m m m O{}}{%
  \luadirect{ekddrama.newrole(
    \luastringN{#1}, % id
    \luastringN{#2}, % role
    \luastringN{#3}, % roleDesc
    \luastringO{#4})} % actor as simple optional string
}
\@onlypreamble\DeclareCast

\NewDocumentCommand{\CastTableBody}{}{%
  \luadirect{tex.print(ekddrama.cast_table())}
}
```

En ce qui concerne la génération du tableau et son encodage en `XML-TEI`, il convient de consulter le fichier `.lua`.

```lua
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

[...]

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

[...]
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

```

Enfin, l'utilisation d'identifiants me permet de simplifier la référence et la manière dont les noms des personnages sont utilisés. Ces derniers sont accessibles via la commande `\loc`, pour locuteur/locutrice, qui, dans mon fichier `.lua`, est toujours construite à partir de l'identifiants et génère le code imbriqué pour le personnage qui parle `<sp who="#%s"><speaker>%s</speaker>`.

```lua
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
```