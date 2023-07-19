@testitem "Integration tests" begin

include("test-data.jl")
using .TestData: params_df, model_fit_df


using GroupedTables #: grouped_table
using Chain, DataFrames, DataFrameMacros
using Test

let
	row_label_var = :description
	row_group_label_var = :group
	column_label_var = :Group_1
	value_var = :value
	spanner_column_label_var = :Group_2
	caption = "Here's some nice caption"
	
	df = @chain params_df begin
		@subset(:Group_2 == "AA", :Group_3 == "Red")
		select(Not(["calibration", "Group_3"]))
	end
	
	specs = (; row_group_label_var, spanner_column_label_var, column_label_var, value_var, row_label_var)
    output = "\\caption{Here's some nice caption}\n\\begin{tabular}{lcc}\n\\toprule \n & \\multicolumn{2}{c}{AA} \\\\\n\\cmidrule(l{2pt}r{2pt}){2-3} description & good & bad \\\\\n\\midrule \n\\multicolumn{3}{l}{\\emph{Preferences}} \\\\\naverage life-time & 45.0 & 1.0 \\\\\ndiscount factor & 0.05 & 0.022 \\\\\nutility weight of housing & 0.5 & 1.0 \\\\\nelasticity of substitution & 1.0 &  \\\\\nstrength of the comparison motive & 0.31 & 0.15 \\\\\n\\multicolumn{3}{l}{\\emph{Technology}} \\\\\nhousing supply elasticity & 1.5 & 0.6 \\\\\ndepreciation rate of housing & 0.052 & 0.07 \\\\\nflow of land permits & 1.0 & 50.0 \\\\\n\\bottomrule \n\\end{tabular}\n\n"
    @test grouped_table(df; caption, specs...) == output
end

let
	specs = (;
		row_label_var = :description,
		#row_group_label_var = :group,
		column_label_var = :Group_3,
		value_var = :value,
		spanner_column_label_var = :Group_2
	)

	df = @chain params_df begin
		DataFrame
		@transform!(
			@subset(:Group_2 == "BB", :Group_3 == "Blue"),
			:Group_3 = "Green"
		)
		@subset(#:group=="Preferences", 
			:Group_1 == "good")
		select(Not([:Group_1, :group, :calibration]))
	end

    output = "\\begin{tabular}{lcccc}\n\\toprule \n & \\multicolumn{2}{c}{AA} & \\multicolumn{2}{c}{BB} \\\\\n\\cmidrule(l{2pt}r{2pt}){2-3} \\cmidrule(l{2pt}r{2pt}){4-5} description & Red & Blue & Red & Green \\\\\n\\midrule \naverage life-time & 45.0 & 36.0 & 50.0 & 40.0 \\\\\ndiscount factor & 0.05 & 0.04 &  & 0.056 \\\\\nutility weight of housing & 0.5 &  & 0.6 & 0.48 \\\\\nelasticity of substitution & 1.0 & 0.8 & 0.15 & 0.12 \\\\\nstrength of the comparison motive & 0.31 & 0.25 & 0.32 &  \\\\\nhousing supply elasticity & 1.5 & 1.2 & 1.0 & 0.8 \\\\\ndepreciation rate of housing & 0.052 & 0.042 &  & 0.018 \\\\\nflow of land permits & 1.0 &  & 1.0 & 0.8 \\\\\n\\bottomrule \n\\end{tabular}\n"
	@test grouped_table(df; specs...) == output
end

let
	row_label_var = :description
	row_group_label_var = :group
	column_label_var = :Group_1
	value_var = :value
	spanner_column_label_var = :Group_2

	df = @chain params_df begin
		@subset(:Group_2 == "BB", :Group_3  == "Red")
		select(Not([:Group_2, :Group_3, :calibration]))
	end
	specs = (; column_label_var, value_var, row_label_var, row_group_label_var)
    output = "\\begin{tabular}{lcc}\n\\toprule \ndescription & good & bad \\\\\n\\midrule \n\\multicolumn{3}{l}{\\emph{Preferences}} \\\\\naverage life-time & 50.0 &  \\\\\ndiscount factor &  & 0.052 \\\\\nutility weight of housing & 0.6 & 1.5 \\\\\nelasticity of substitution & 0.15 & 0.31 \\\\\nstrength of the comparison motive & 0.32 & 1.0 \\\\\n\\multicolumn{3}{l}{\\emph{Technology}} \\\\\nhousing supply elasticity & 1.0 &  \\\\\ndepreciation rate of housing &  & 0.05 \\\\\nflow of land permits & 1.0 & 45.0 \\\\\n\\bottomrule \n\\end{tabular}\n"
	@test grouped_table(df; specs...) == output
end

let
	row_label_var = :description
	row_group_label_var = :Group_3 #:group
	column_label_var = :Group_1
	value_var = :value
	spanner_column_label_var = :Group_2

	df = @chain params_df begin
		@subset(:group == "Preferences")
		select(Not(["calibration", "group"]))
		@transform!(
			@subset(:Group_2 == "BB", :Group_1 == "bad", :Group_3 == "Red"),
			:Group_1 = "mediocre"
		)
	end
	specs = (; column_label_var, value_var, row_label_var, row_group_label_var, spanner_column_label_var)
    output = "\\begin{tabular}{lccccc}\n\\toprule \n & \\multicolumn{2}{c}{AA} & \\multicolumn{3}{c}{BB} \\\\\n\\cmidrule(l{2pt}r{2pt}){2-3} \\cmidrule(l{2pt}r{2pt}){4-6} description & good & bad & good & bad & mediocre \\\\\n\\midrule \n\\multicolumn{6}{l}{\\emph{Red}} \\\\\naverage life-time & 45.0 & 1.0 & 50.0 &  &  \\\\\ndiscount factor & 0.05 & 0.022 &  &  & 0.052 \\\\\nutility weight of housing & 0.5 & 1.0 & 0.6 &  & 1.5 \\\\\nelasticity of substitution & 1.0 &  & 0.15 &  & 0.31 \\\\\nstrength of the comparison motive & 0.31 & 0.15 & 0.32 &  & 1.0 \\\\\n\\multicolumn{6}{l}{\\emph{Blue}} \\\\\naverage life-time & 36.0 & 0.8 & 40.0 & 0.8 &  \\\\\ndiscount factor & 0.04 &  & 0.056 & 0.042 &  \\\\\nutility weight of housing &  & 0.8 & 0.48 & 1.2 &  \\\\\nelasticity of substitution & 0.8 & 0.26 & 0.12 &  &  \\\\\nstrength of the comparison motive & 0.25 & 0.12 &  & 0.8 &  \\\\\n\\bottomrule \n\\end{tabular}\n"
	@test grouped_table(df; specs...) == output
end

let
	row_label_var = :description
	#row_group_label_var = :group
	column_label_var = :Group_1
	value_var = :value
	spanner_column_label_var = :Group_2

	df = @chain params_df begin
		@subset(:group == "Preferences", :Group_2 == "AA", :Group_3 == "Red")
		select(Not([:group, :Group_2, :Group_3, :calibration]))
	end
	specs = (; column_label_var, value_var, row_label_var)
	output = "\\begin{tabular}{lcc}\n\\toprule \ndescription & good & bad \\\\\n\\midrule \naverage life-time & 45.0 & 1.0 \\\\\ndiscount factor & 0.05 & 0.022 \\\\\nutility weight of housing & 0.5 & 1.0 \\\\\nelasticity of substitution & 1.0 &  \\\\\nstrength of the comparison motive & 0.31 & 0.15 \\\\\n\\bottomrule \n\\end{tabular}\n"
    @test grouped_table(df; specs...) == output
end

@test grouped_table(model_fit_df;
	row_label_var = :Moment,
	value_var = :value,
	row_group_label_var = :row_group, 
	spanner_column_label_var = :spanner, 
	column_label_var = :version, 
	extra_columns = [:Target, :Source] 
) == "\\begin{tabular}{lcccccc}\n\\toprule \n & \\multicolumn{2}{c}{Group 1} & \\multicolumn{2}{c}{Group 2} \\\\\n\\cmidrule(l{2pt}r{2pt}){2-3} \\cmidrule(l{2pt}r{2pt}){4-5} Moment & Baseline & Extension & Baseline & Extension & Target & Source \\\\\n\\midrule \n\\multicolumn{5}{l}{\\emph{AAA}} \\\\\nEmployment share & 0.04 & 0.06 & 0.47 & 0.45 & 0.05 & Kaplan et al. (2020) \\\\\n\\multicolumn{5}{l}{\\emph{BBB}} \\\\\nExpenditure share & 0.15 & 0.17 & 0.17 & 0.15 & 0.162 & CEX (1982) \\\\\nMortgage-to-income & 0.45 & 0.47 & 0.06 & 0.04 & 0.462 & DINA (1980) \\\\\n\\bottomrule \n\\end{tabular}\n"


@chain model_fit_df begin
	select(Not([:row_group, :Target, :Source]))
	grouped_table(
		row_label_var = :Moment,
		 value_var = :value,
		 spanner_column_label_var = :spanner,
		 column_label_var = :version 
	)
	@test _ == "\\begin{tabular}{lcccc}\n\\toprule \n & \\multicolumn{2}{c}{Group 1} & \\multicolumn{2}{c}{Group 2} \\\\\n\\cmidrule(l{2pt}r{2pt}){2-3} \\cmidrule(l{2pt}r{2pt}){4-5} Moment & Baseline & Extension & Baseline & Extension \\\\\n\\midrule \nEmployment share & 0.04 & 0.06 & 0.47 & 0.45 \\\\\nExpenditure share & 0.15 & 0.17 & 0.17 & 0.15 \\\\\nMortgage-to-income & 0.45 & 0.47 & 0.06 & 0.04 \\\\\n\\bottomrule \n\\end{tabular}\n"
end

@chain model_fit_df begin
	select(Not(:row_group))
	grouped_table(
		row_label_var = :Moment,
		value_var = :value,
		spanner_column_label_var = :spanner,
		column_label_var = :version,
		extra_columns = [:Target, :Source]
	)
	@test _ == "\\begin{tabular}{lcccccc}\n\\toprule \n & \\multicolumn{2}{c}{Group 1} & \\multicolumn{2}{c}{Group 2} \\\\\n\\cmidrule(l{2pt}r{2pt}){2-3} \\cmidrule(l{2pt}r{2pt}){4-5} Moment & Baseline & Extension & Baseline & Extension & Target & Source \\\\\n\\midrule \nEmployment share & 0.04 & 0.06 & 0.47 & 0.45 & 0.05 & Kaplan et al. (2020) \\\\\nExpenditure share & 0.15 & 0.17 & 0.17 & 0.15 & 0.162 & CEX (1982) \\\\\nMortgage-to-income & 0.45 & 0.47 & 0.06 & 0.04 & 0.462 & DINA (1980) \\\\\n\\bottomrule \n\\end{tabular}\n"
end


@chain model_fit_df begin
	@subset(:spanner == "Group 1")
	select(Not([:row_group]))
	grouped_table(
		row_label_var = :Moment,
		value_var = :value,
		spanner_column_label_var = :spanner,
		column_label_var = :version,
		extra_columns = [:Target, :Source]
	)
	@test _ == "\\begin{tabular}{lcccc}\n\\toprule \n & \\multicolumn{2}{c}{Group 1} \\\\\n\\cmidrule(l{2pt}r{2pt}){2-3} Moment & Baseline & Extension & Target & Source \\\\\n\\midrule \nEmployment share & 0.04 & 0.06 & 0.05 & Kaplan et al. (2020) \\\\\nExpenditure share & 0.15 & 0.17 & 0.162 & CEX (1982) \\\\\nMortgage-to-income & 0.45 & 0.47 & 0.462 & DINA (1980) \\\\\n\\bottomrule \n\\end{tabular}\n"	
end

end