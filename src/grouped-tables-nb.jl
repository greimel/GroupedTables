### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# ╔═╡ 470f9829-703d-4d88-bb33-3ac63edeebd9
using DataFrames

# ╔═╡ 9b69006f-5e8c-4b19-b32f-fd41d7e2e8f9
using LaTeXTabulars

# ╔═╡ c4829b4d-a999-409c-b259-562079b5345e
using Chain

# ╔═╡ 8a6f584d-7cc7-4c4b-b548-fabe45612ee2
using DataAPI: levels

# ╔═╡ 2470bd26-71c9-4e89-aa0a-7919664a303f
# ╠═╡ skip_as_script = true
#=╠═╡
using DataFrameMacros
  ╠═╡ =#

# ╔═╡ 9e0a05f9-113d-482c-85b9-3f4017fadce6
# ╠═╡ skip_as_script = true
#=╠═╡
using CategoricalArrays: categorical, levels!
  ╠═╡ =#

# ╔═╡ f1df3c8b-0551-4e91-90bd-70a9d36528dc
# ╠═╡ skip_as_script = true
#=╠═╡
using PlutoUI
  ╠═╡ =#

# ╔═╡ 36b9fd64-5802-4fe8-9378-55d7ed2c7cbf
# ╠═╡ skip_as_script = true
#=╠═╡
using LaTeXStrings
  ╠═╡ =#

# ╔═╡ c8ebbb34-6804-4cda-90eb-ccd33dd1be72
md"""
# Something like `gt`: A grammar for tables
"""

# ╔═╡ 377705b3-8612-47df-b2f4-8394eeb880e3
md"""
## Spanner column labels
"""

# ╔═╡ 8c8c7f03-11c9-4258-9303-fe8d2dbd484d
md"""
## Body
"""

# ╔═╡ c94f9cfa-3ef4-4a7d-a350-188d64492be3
function construct_body(row_labels, body, extra_body, row_group_label, N)
	mapreduce(vcat, zip(row_labels, body, extra_body, row_group_label)) do (rg_row_labels, rg_body, rg_xtr_body, rg_label)
		label = ismissing(rg_label) ? [] : [[MultiColumn(N+1, :l, "\\emph{$rg_label}")]]
		[
			label..., 
			isempty(rg_xtr_body) ? [rg_row_labels rg_body] : [rg_row_labels rg_body rg_xtr_body]
		]
	end
end

# ╔═╡ 085e7681-b1e2-48c6-a024-7ffe3205a96a
md"""
## Top part
"""

# ╔═╡ d10afd7a-1066-41db-8914-ca3ff760cfbe
# construct top part with spanner column labels
function construct_top_part(spanner_column_labels, stubhead_label, headers, extra_headers)
	ns = length.(headers)
	cns = cumsum([1; ns])
	
	[
		# spanner column labels
		[""; MultiColumn.(ns, :c, spanner_column_labels)],
		# broken midrules
		(CMidRule("l{2pt}r{2pt}", cns[i] + 1 , cns[i+1]) for i ∈ 1:(length(cns)-1))...,
		# headers
		[stubhead_label headers... extra_headers...]
	]
end

# ╔═╡ 080ec2da-43ec-4fc6-b3a5-f17d186b1cbc
# construct top part without spanner column labels
construct_top_part(spanner_column_labels::Array{Missing}, stubhead_label, headers, extra_headers) =
	[[stubhead_label headers... extra_headers...]]

# ╔═╡ e4303bac-27cb-4c9c-b08a-58ea221d6d77
md"""
## Basic components
"""

# ╔═╡ 60d5ec48-ca3c-4493-9a9f-94f33a8f9528
function delete_empty_columns(body, headers, nonempty_columns)
	headers = getindex.(headers, Ref(1:1), nonempty_columns)
		
	for i ∈ eachindex(body)
		body[i] = body[i][:, vcat(nonempty_columns...)]
	end

	(; body, headers)
end

# ╔═╡ 8131f528-a763-45ea-8286-81275b59a57c
function drop_if_present(df, col::Union{Symbol,AbstractString})
	if string(col) ∈ names(df)
		select(df, Not(col))
	else
		df
	end
end

# ╔═╡ 95fbbb01-f3fa-46d0-a403-50140ae92cfe
drop_if_present(df, col) = df

# ╔═╡ b0b4453b-9fdb-4f21-8f10-8efeb0bd1163
function table_helper(tbl, row_label_var, row_labels=getproperty(tbl, row_label_var))
	body = @chain begin
		DataFrame(row_label_var => row_labels)
		leftjoin!(tbl, on = row_label_var)
		select(Not(row_label_var))
		@aside headers = reshape(names(_), 1, :)
		Matrix
		coalesce.(_, "")
	end

	(; headers, body, row_labels)
end

# ╔═╡ fcd84f30-2e4f-47f7-8cb5-5a8ae73355a5
function table_helper_row_group(
			wide_tbl;
			extra_columns = Symbol[],
			spanner_column_label_var=missing,
			row_label_var, overall_row_labels
		)
	
	row_labels = overall_row_labels ∩ getproperty(wide_tbl, row_label_var)
	
	if !ismissing(spanner_column_label_var)
		grouped_tbl = pairs(groupby(wide_tbl, spanner_column_label_var))
	else
		grouped_tbl = [missing => wide_tbl]
	end

	contents = map(grouped_tbl) do (gkey, tbl)
		xtra = select(tbl, extra_columns)
		tbl  = select(tbl, Not(extra_columns))
		
		out = table_helper(
			drop_if_present(tbl, spanner_column_label_var), 
			row_label_var, row_labels)
		spanner_column_label = ismissing(gkey) ? missing : only(values(gkey))
		(; out..., spanner_column_label, xtra)
	end |> DataFrame

	xtra = only(unique(contents.xtra))
	extra_headers = reshape(names(xtra), 1, :)
	extra_body = Matrix(xtra)
	
	# determine non-empty columns
	body = hcat(contents.body...)

	nonempty_columns = map(contents.body) do b
		any.(!=(""), eachcol(b))
	end

	(; spanner_column_labels = contents.spanner_column_label, 
		contents.headers,
		row_labels, body,
		extra_headers,
		extra_body,
#		row_labels_and_body = [row_labels body],
		stubhead_label = string(row_label_var),
		nonempty_columns,		
	)

end

# ╔═╡ 2ab314be-8b2f-45c3-b921-6c83e9d81b78
function basic_components(
		wide_tbl, specs, overall_row_labels,
		row_group_label_var::Missing
	)
	# no row groups
	contents = table_helper_row_group(
		wide_tbl;
		specs...,
		overall_row_labels
	)

	(; headers, body) = delete_empty_columns(
		[contents.body],
		contents.headers,
		contents.nonempty_columns
	)
	
	(; 
		body, headers, contents.extra_headers,
		extra_body = [contents.extra_body],
		contents.spanner_column_labels,
		contents.stubhead_label,
		row_labels = [contents.row_labels],
		row_group_label = [missing]
	)
end

# ╔═╡ 34ab08d4-84db-4c71-a236-b47516483264
function basic_components(
		wide_tbl, specs, overall_row_labels,
		row_group_label_var
	)
	## row groups present
	row_grouped_tbl = pairs(groupby(wide_tbl, row_group_label_var))
	
	contents = map(row_grouped_tbl) do (gkey, tbl)
		row_group_label     = only(values(gkey))
	
		out = table_helper_row_group(
			select(tbl, Not(row_group_label_var));
			specs...,
			overall_row_labels
		)
	
		(; out..., row_group_label)
	end |> DataFrame

	# determine nonempty columns
	nonempty_columns = copy(first(contents.nonempty_columns))
	for x ∈ contents.nonempty_columns[2:end]
		nonempty_columns = map(.|, nonempty_columns, x)
	end

	(; headers, body) = delete_empty_columns(
		contents.body,
		only(unique(contents.headers)),
		nonempty_columns
	)

	(; 
		body, headers, 
		extra_headers = only(unique(contents.extra_headers)),
		contents.extra_body,
		spanner_column_labels = only(unique(contents.spanner_column_labels)),
		stubhead_label        = only(unique(contents.stubhead_label)),
		contents.row_labels, 
		contents.row_group_label
	)
end

# ╔═╡ 3a08e6fa-46ca-4615-b202-e211f4cce424
function table_components(tbl; row_group_label_var=missing, column_label_var, value_var, specs...)
	
	specs = NamedTuple(specs)
	
	overall_row_labels = levels(getproperty(tbl, specs.row_label_var))
	
	# unstack columns, so that all groups have same columns
	wide_tbl = unstack(tbl, column_label_var, value_var)
	
	# construct basic components
	(; row_labels, body, row_group_label,
	   spanner_column_labels, headers, stubhead_label,
	   extra_headers, extra_body
	) = basic_components(
		wide_tbl, specs, overall_row_labels,
		row_group_label_var
	)
			
	N = sum(length.(headers))

	body_vec = construct_body(row_labels, body, extra_body, row_group_label, N) #, 
	
	# construct top part
	top_part = construct_top_part(spanner_column_labels, stubhead_label, headers, extra_headers)

	(; top_part, body_vec, N=N+length(extra_headers))
end

# ╔═╡ 7a7879f2-6117-4f9f-8080-0effa0d27711
function grouped_table(tbl; caption=missing, specs...)

	(; top_part, body_vec, N) = table_components(tbl; specs...)

	tabular = latex_tabular(
		String,
		Tabular("l" * "c"^N),
		[
			Rule(:top);
			top_part;
			Rule(:mid);
			body_vec;
			Rule(:bottom)
		]		
	)

	if !ismissing(caption)
		"""
		\\caption{$caption}
		$tabular
		"""
	else
		tabular
	end
end

# ╔═╡ d0624fa7-c9e3-444c-9b5e-6e6372a213c2
md"""
### Test
"""

# ╔═╡ 242b9caf-f630-413d-9db7-2fad867621f0
# ╠═╡ skip_as_script = true
#=╠═╡
df0 = DataFrame(
	description = ["average life-time", "discount factor", "utility weight of housing", "elasticity of substitution", "strength of the comparison motive", "housing supply elasticity", "depreciation rate of housing", "flow of land permits"],
	group = ["Preferences", "Preferences", "Preferences", "Preferences", "Preferences", "Technology", "Technology", "Technology"],
	calibration = ["external", "internal", "internal", "external", "internal", "external", "internal", "ad hoc"],
	AA = [45.0, 0.05, 0.5, 1.0, 0.31, 1.5, 0.052, 1.0],
	BB = [50.0, 0.07, 0.6, 0.15, 0.32, 1.0, 0.022, 1.0]
)
  ╠═╡ =#

# ╔═╡ cc264088-16bb-4487-ac24-dd2a17708673
#=╠═╡
params_df = @chain df0 begin
	transform!(:description => categorical, renamecols=false)
	@aside levels!(_.description, ["average life-time", "discount factor", "utility weight of housing", "elasticity of substitution", "strength of the comparison motive", "housing supply elasticity", "depreciation rate of housing", "flow of land permits"])
	stack([:AA, :BB], value_name = :good, variable_name = "Group_2")
	transform(:good => reverse => :bad)
	stack([:good, :bad], variable_name = "Group_1", value_name = :Red)
	@transform(:Blue = 0.8 * :Red)
	stack([:Red, :Blue], variable_name = "Group_3")
	@transform(:value = round(:value, sigdigits=2))
	@aside _[10:5:64,:value] .= NaN
	@subset!(!isnan(:value))
end
  ╠═╡ =#

# ╔═╡ 5e6db61d-c3ed-4f9c-8fac-8daa8799445a
#=╠═╡
let
	row_label_var = :description
	spanner_column_label_var = Symbol("Group_1")
	gdf = groupby(params_df, spanner_column_label_var)[1]

	table_helper(gdf, row_label_var, spanner_column_label_var)
end
  ╠═╡ =#

# ╔═╡ 0b18db95-05ff-4cf9-99c3-671f90ce5543
md"""
# Other tests
"""

# ╔═╡ 9ccd40cf-7722-421b-95be-658bd86ec336
# ╠═╡ skip_as_script = true
#=╠═╡
new_df0 = DataFrame(
	Moment = ["Employment share", "Expenditure share", "Mortgage-to-income"],
	Target = [0.05, 0.162, 0.462],
	Source = ["Kaplan et al. (2020)", "CEX (1982)", "DINA (1980)"],
	Baseline = [0.04, 0.15, 0.45],
	Extension = [0.06, 0.17, 0.47]
)
  ╠═╡ =#

# ╔═╡ 009cb6eb-3be9-4c0b-a3b4-0bc444674df1
#=╠═╡
new_df = @chain new_df0 begin
	stack(["Baseline", "Extension"], variable_name = "version", value_name = "Group 1")
	@transform("Group 2" = @bycol reverse({"Group 1"}))
	stack(["Group 1", "Group 2"], variable_name = :spanner)
	@transform(:row_group = :Moment == "Employment share" ? "AAA" : "BBB")
end
  ╠═╡ =#

# ╔═╡ 235e7816-b0d2-4a98-bba5-12351f9a8d51
md"""
# Appendix
"""

# ╔═╡ f9d0c823-7443-48fc-9c0a-d1407e4ea2ae
#=╠═╡
TableOfContents()
  ╠═╡ =#

# ╔═╡ 311d093a-be4d-4c98-b5d5-91038d37bf5c
md"""
## Render latex snippets
"""

# ╔═╡ 1e552946-f9df-43c7-b4ad-9690ff4396c7
# ╠═╡ skip_as_script = true
#=╠═╡
import tectonic_jll, Poppler_jll
  ╠═╡ =#

# ╔═╡ 95fa9a3c-5ea5-4593-b94e-395c46d20d32
usepackage(names...) = join("\\usepackage{" .* names .* "}", "\n")

# ╔═╡ ad3cccf0-4e78-4e70-b4c9-95d632340384
usepackage("amsmath", "booktabs", "threeparttable")

# ╔═╡ 6a422d82-db89-4345-a74e-d722224aa0f6
table_buffer(content; packages=String[]) = """
\\documentclass{standalone}
$(usepackage(packages...))
\\usepackage{standalone}
\\usepackage{caption}
\\usepackage{booktabs}

\\begin{document}

%\\begin{centering}
%\\begin{table}
$content
%\\end{table}
%\\end{centering}

\\end{document}

""" |> String;

# ╔═╡ f1fa298f-f442-4d97-946b-99987debde4f
# ╠═╡ disabled = true
#=╠═╡
L"""
\documentclass[border=2pt]{standalone}
\usepackage{booktabs,threeparttable,dcolumn}
\newcolumntype{d}[1]{D..{#1}}
\newcommand\mc[1]{\multicolumn{1}{c@{}}{#1}} % handy shortcut macro

\begin{document}

\begin{threeparttable}
Random caption inserted as a placeholder for what I am actually going to say, which will be a sentence or two long in the end I think.

\begin{tabular}{@{} l d{2.3} @{}}
\toprule
 & \mc{Initiate conflict} \\
\midrule
First = female                     & -0.08      \\
                                   & (0.05)     \\
Second = prefer not to say         & -0.21      \\
                                   & (0.18)     \\
Third = non-binary/non-conforming  & -0.18      \\
                                   & (0.12)     \\
(Intercept)                        & 0.35^{***} \\
                                   & (0.03)     \\
\addlinespace
R$^2$                              & 0.01       \\
Adj.\ R$^2$                        & 0.01       \\
Num.\ obs.                         & \mc{404}   \\
\midrule[\heavyrulewidth]
\multicolumn{2}{@{}l}{\scriptsize $^{***}\ p<0.001$; $^{**}\ p<0.01$; $^{*}\ p<0.05$} 
\end{tabular}

\begin{tablenotes}
Here are some table notes.
\end{tablenotes}

\end{threeparttable}

\end{document}
""" |> preview_latex_document
  ╠═╡ =#

# ╔═╡ fb2c1d60-b5a1-4371-91c0-18d43cb7248a
#=╠═╡
# taken from MakieTeX
function pdf2svg(pdf::Vector{UInt8}; page=1, kwargs...)
     pdftocairo = Poppler_jll.pdftocairo() do exe
         open(`$exe -f $page -l $page -svg - -`, "r+")
     end

     write(pdftocairo, pdf)

     close(pdftocairo.in)

     return read(pdftocairo.out, String)
 end
  ╠═╡ =#

# ╔═╡ 6c680a1a-5ac5-4c2d-bb28-d1e3a5191cab
# ╠═╡ skip_as_script = true
#=╠═╡
begin
	struct HTMLDocument
	    embedded
	end
	
	function Base.show(io::IO, mime::MIME"text/html", doc::HTMLDocument)
	    println(io, "<html>")
	    show(io, mime, doc.embedded)
	    println(io, "</html>")
	end
end
  ╠═╡ =#

# ╔═╡ b7b1d236-0eeb-4a00-acfe-f7395d130f7b
# ╠═╡ skip_as_script = true
#=╠═╡
pdf2svg(pdf::String) = pdf2svg(Vector{UInt8}(pdf))
  ╠═╡ =#

# ╔═╡ 526f3979-2bcb-4f1e-af99-8411d0d61afa
#=╠═╡
function preview_latex_document(buffer; show_messages = false, basefile = tempname())
	@info basefile
	texfile = basefile * ".tex"
	pdffile = basefile * ".pdf"

	write(texfile, buffer * "")

	original_stdout = stdout
	(rd, wr) = redirect_stdout()
	
	tectonic_jll.tectonic() do bin
		run(`$bin --print $texfile`)
	end	
	redirect_stdout(original_stdout)

	close(wr)

	if show_messages
		s = read(rd, String)
		@info s
	end

	pdf2svg(read(pdffile)) |> HTML |> HTMLDocument

end
  ╠═╡ =#

# ╔═╡ 0e1fa8e2-7b93-419c-a70a-f8e80f435c89
#=╠═╡
function preview_latex_table(content; packages=String[], kwargs...)
	preview_latex_document(table_buffer(content * ""; packages); kwargs...)
end
  ╠═╡ =#

# ╔═╡ f0dab509-638f-468b-910d-1d6ddfac2c6a
#=╠═╡
@chain new_df begin
	select(Not(:row_group))
	grouped_table(row_label_var = :Moment, value_var = :value, spanner_column_label_var = :spanner, column_label_var = :version, extra_columns = [:Target, :Source] )
	#Text
	preview_latex_table
end
  ╠═╡ =#

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CategoricalArrays = "324d7699-5711-5eae-9e2f-1d82baa6b597"
Chain = "8be319e6-bccf-4806-a6f7-6fae938471bc"
DataAPI = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
DataFrameMacros = "75880514-38bc-4a95-a458-c2aea5a3a702"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
LaTeXStrings = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
LaTeXTabulars = "266f59ce-6e72-579c-98bb-27b39b5c037e"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Poppler_jll = "9c32591e-4766-534b-9725-b71a8799265b"
tectonic_jll = "d7dd28d6-a5e6-559c-9131-7eb760cdacc5"

[compat]
CategoricalArrays = "~0.10.8"
Chain = "~0.5.0"
DataAPI = "~1.15.0"
DataFrameMacros = "~0.4.1"
DataFrames = "~1.5.0"
LaTeXStrings = "~1.3.0"
LaTeXTabulars = "~0.1.2"
PlutoUI = "~0.7.51"
Poppler_jll = "~21.9.0"
tectonic_jll = "~0.13.1"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.2"
manifest_format = "2.0"
project_hash = "6a6539b135cf2f9710353b3e2741c09ecf9a1621"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.ArgCheck]]
git-tree-sha1 = "a3a402a35a2f7e0b87828ccabbd5ebfbebe356b4"
uuid = "dce04be8-c92d-5529-be00-80e4d2c0e197"
version = "2.3.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4b859a208b2397a7a623a03449e4636bdb17bcf2"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+1"

[[deps.CategoricalArrays]]
deps = ["DataAPI", "Future", "Missings", "Printf", "Requires", "Statistics", "Unicode"]
git-tree-sha1 = "1568b28f91293458345dabba6a5ea3f183250a61"
uuid = "324d7699-5711-5eae-9e2f-1d82baa6b597"
version = "0.10.8"

    [deps.CategoricalArrays.extensions]
    CategoricalArraysJSONExt = "JSON"
    CategoricalArraysRecipesBaseExt = "RecipesBase"
    CategoricalArraysSentinelArraysExt = "SentinelArrays"
    CategoricalArraysStructTypesExt = "StructTypes"

    [deps.CategoricalArrays.weakdeps]
    JSON = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
    SentinelArrays = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
    StructTypes = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"

[[deps.Chain]]
git-tree-sha1 = "8c4920235f6c561e401dfe569beb8b924adad003"
uuid = "8be319e6-bccf-4806-a6f7-6fae938471bc"
version = "0.5.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.Compat]]
deps = ["UUIDs"]
git-tree-sha1 = "4e88377ae7ebeaf29a047aa1ee40826e0b708a5d"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.7.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.5+0"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "8da84edb865b0b5b0100c0666a9bc9a0b71c553c"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.15.0"

[[deps.DataFrameMacros]]
deps = ["DataFrames", "MacroTools"]
git-tree-sha1 = "5275530d05af21f7778e3ef8f167fb493999eea1"
uuid = "75880514-38bc-4a95-a458-c2aea5a3a702"
version = "0.4.1"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Random", "Reexport", "SentinelArrays", "SnoopPrecompile", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "aa51303df86f8626a962fccb878430cdb0a97eee"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.5.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "cf25ccb972fec4e4817764d01c82386ae94f77b4"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.14"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "4558ab818dcceaab612d1bb8c19cee87eda2b83c"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.5.0+0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "d8db6a5a2fe1381c1ea4ef2cab7c69c2de7f9ea0"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.13.1+0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "d3b3624125c1474292d0d8ed0f65554ac37ddb23"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.74.0+2"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[deps.HarfBuzz_ICU_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "HarfBuzz_jll", "ICU_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "6ccbc4fdf65c8197738c2d68cc55b74b19c97ac2"
uuid = "655565e8-fb53-5cb3-b0cd-aec1ca0647ea"
version = "2.8.1+0"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[deps.ICU_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "20b6765a3016e1fca0c9c93c80d50061b94218b7"
uuid = "a51ab1cf-af8e-5615-a023-bc2c838bba6b"
version = "69.1.0+0"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "d75853a0bdbfb1ac815478bacd89cd27b550ace6"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.3"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "9cc2baf75c6d09f9da536ddf58eb2f29dedaf461"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InvertedIndices]]
git-tree-sha1 = "0dc7b50b8d436461be01300fd8cd45aa0274b038"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6f2675ef130a300a112286de91973805fcc5ffbc"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.91+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bf36f528eec6634efc60d7ec062008f171071434"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "3.0.0+1"

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f689897ccbe049adb19a065c495e75f372ecd42b"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "15.0.4+0"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.LaTeXTabulars]]
deps = ["ArgCheck", "DocStringExtensions", "UnPack"]
git-tree-sha1 = "46be3cade8052a27932e3cc52836018cb051e1f3"
uuid = "266f59ce-6e72-579c-98bb-27b39b5c037e"
version = "0.1.2"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c7cb1f5d892775ba13767a87c7ada0b980ea0a71"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+2"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "3eb79b0ca5764d4799c06699573fd8f533259713"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.4.0+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LittleCMS_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pkg"]
git-tree-sha1 = "110897e7db2d6836be22c18bffd9422218ee6284"
uuid = "d3a379c0-f9a3-5b72-a4c0-6bf4d2e8af0f"
version = "2.12.0+0"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.10.11"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.21+4"

[[deps.OpenJpeg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libtiff_jll", "LittleCMS_jll", "Pkg", "libpng_jll"]
git-tree-sha1 = "76374b6e7f632c130e78100b166e5a48464256f8"
uuid = "643b3616-a352-519d-856d-80112ee9badc"
version = "2.4.0+0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1aa4b74f80b01c6bc2b89992b861b5f210e665b5"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.21+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "d321bf2de576bf25ec4d3e4360faca399afca282"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.0"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.42.0+0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "4b2e829ee66d4218e0cef22c0a64ee37cf258c29"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.7.1"

[[deps.Pixman_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LLVMOpenMP_jll", "Libdl"]
git-tree-sha1 = "64779bc4c9784fee475689a1752ef4d5747c5e87"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.42.2+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.2"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "b478a748be27bd2f2c73a7690da219d0844db305"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.51"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a6062fe4063cdafe78f4a0a81cfffb89721b30e7"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.2"

[[deps.Poppler_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "OpenJpeg_jll", "Pkg", "libpng_jll"]
git-tree-sha1 = "02148a0cb2532f22c0589ceb75c110e168fb3d1f"
uuid = "9c32591e-4766-534b-9725-b71a8799265b"
version = "21.9.0+0"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "9673d39decc5feece56ef3940e5dafba15ba0f81"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.1.2"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "7eb1686b4f04b82f96ed7a4ea5890a4f0c7a09f1"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.0"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "LaTeXStrings", "Markdown", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "213579618ec1f42dea7dd637a42785a608b1ea9c"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.2.4"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "04bdff0b09c65ff3e06a05e3eb7b120223da3d39"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SnoopPrecompile]]
deps = ["Preferences"]
git-tree-sha1 = "e760a70afdcd461cf01a575947738d359234665c"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "c60ec5c62180f27efea3ba2908480f8055e17cee"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.1.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.StringManipulation]]
git-tree-sha1 = "46da2434b41f41ac3594ee9816ce5541c6096123"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.3.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "5.10.1+6"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "1544b926975372da01227b382066ab70e574a3ec"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.10.1"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.Tricks]]
git-tree-sha1 = "aadb748be58b492045b4f56166b5188aa63ce549"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.7"

[[deps.URIs]]
git-tree-sha1 = "074f993b0ca030848b897beff716d93aca60f06a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.2"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "93c41695bc1c08c46c5899f4fe06d6ead504bb73"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.10.3+0"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "afead5aba5aa507ad5a3bf01f58f82c8d1403495"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.6+0"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6035850dcc70518ca32f012e46015b9beeda49d8"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.11+0"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "34d526d318358a859d7de23da945578e8e8727b7"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.4+0"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8fdda4c692503d44d04a0603d9ac0982054635f9"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.1+0"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "b4bfde5d5b652e22b9c790ad00af08b6d042b97d"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.15.0+0"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e92a1a012a10506618f10b7047e478403a046c77"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.5.0+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "49ce682769cd5de6c72dcf1b94ed7790cd08974c"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.5+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"

[[deps.tectonic_jll]]
deps = ["Artifacts", "Fontconfig_jll", "FreeType2_jll", "Graphite2_jll", "HarfBuzz_ICU_jll", "HarfBuzz_jll", "ICU_jll", "JLLWrappers", "Libdl", "OpenSSL_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "54867b00af20c70b52a1f9c00043864d8b926a21"
uuid = "d7dd28d6-a5e6-559c-9131-7eb760cdacc5"
version = "0.13.1+0"
"""

# ╔═╡ Cell order:
# ╟─c8ebbb34-6804-4cda-90eb-ccd33dd1be72
# ╠═470f9829-703d-4d88-bb33-3ac63edeebd9
# ╠═9b69006f-5e8c-4b19-b32f-fd41d7e2e8f9
# ╠═c4829b4d-a999-409c-b259-562079b5345e
# ╠═8a6f584d-7cc7-4c4b-b548-fabe45612ee2
# ╟─377705b3-8612-47df-b2f4-8394eeb880e3
# ╠═7a7879f2-6117-4f9f-8080-0effa0d27711
# ╠═3a08e6fa-46ca-4615-b202-e211f4cce424
# ╟─8c8c7f03-11c9-4258-9303-fe8d2dbd484d
# ╠═c94f9cfa-3ef4-4a7d-a350-188d64492be3
# ╟─085e7681-b1e2-48c6-a024-7ffe3205a96a
# ╠═d10afd7a-1066-41db-8914-ca3ff760cfbe
# ╠═080ec2da-43ec-4fc6-b3a5-f17d186b1cbc
# ╟─e4303bac-27cb-4c9c-b08a-58ea221d6d77
# ╠═2ab314be-8b2f-45c3-b921-6c83e9d81b78
# ╠═34ab08d4-84db-4c71-a236-b47516483264
# ╠═60d5ec48-ca3c-4493-9a9f-94f33a8f9528
# ╠═8131f528-a763-45ea-8286-81275b59a57c
# ╠═95fbbb01-f3fa-46d0-a403-50140ae92cfe
# ╠═fcd84f30-2e4f-47f7-8cb5-5a8ae73355a5
# ╠═b0b4453b-9fdb-4f21-8f10-8efeb0bd1163
# ╟─d0624fa7-c9e3-444c-9b5e-6e6372a213c2
# ╠═2470bd26-71c9-4e89-aa0a-7919664a303f
# ╠═9e0a05f9-113d-482c-85b9-3f4017fadce6
# ╠═5e6db61d-c3ed-4f9c-8fac-8daa8799445a
# ╠═242b9caf-f630-413d-9db7-2fad867621f0
# ╠═cc264088-16bb-4487-ac24-dd2a17708673
# ╠═0b18db95-05ff-4cf9-99c3-671f90ce5543
# ╠═9ccd40cf-7722-421b-95be-658bd86ec336
# ╠═009cb6eb-3be9-4c0b-a3b4-0bc444674df1
# ╠═f0dab509-638f-468b-910d-1d6ddfac2c6a
# ╟─235e7816-b0d2-4a98-bba5-12351f9a8d51
# ╠═f1df3c8b-0551-4e91-90bd-70a9d36528dc
# ╠═f9d0c823-7443-48fc-9c0a-d1407e4ea2ae
# ╟─311d093a-be4d-4c98-b5d5-91038d37bf5c
# ╠═1e552946-f9df-43c7-b4ad-9690ff4396c7
# ╠═95fa9a3c-5ea5-4593-b94e-395c46d20d32
# ╠═ad3cccf0-4e78-4e70-b4c9-95d632340384
# ╠═6a422d82-db89-4345-a74e-d722224aa0f6
# ╠═36b9fd64-5802-4fe8-9378-55d7ed2c7cbf
# ╠═f1fa298f-f442-4d97-946b-99987debde4f
# ╠═526f3979-2bcb-4f1e-af99-8411d0d61afa
# ╠═0e1fa8e2-7b93-419c-a70a-f8e80f435c89
# ╠═fb2c1d60-b5a1-4371-91c0-18d43cb7248a
# ╠═6c680a1a-5ac5-4c2d-bb28-d1e3a5191cab
# ╠═b7b1d236-0eeb-4a00-acfe-f7395d130f7b
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
