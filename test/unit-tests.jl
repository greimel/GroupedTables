@testitem "Unit tests" begin

include("test-data.jl")
using .TestData: params_df

using GroupedTables: table_helper, table_helper_row_group
using Chain, DataFrames, DataFrameMacros

@chain params_df begin
	@subset(:group == "Preferences", :Group_2 == "AA", :Group_3 == "Red")
	select(Not([:group, :Group_2, :Group_3, :calibration]))
	unstack(:Group_1, :value)
	table_helper(:description, Symbol[], Symbol[])
	@aside @testset "table_helper" begin
		@test _.headers == ["good" "bad"]
		@test _.body == [45 1; 0.05 0.022; 0.5 1.0; 1.0 ""; 0.31 0.15]
		@test _.row_labels[4:5] == ["elasticity of substitution", "strength of the comparison motive"]
	end	
end

@chain params_df begin
	@subset(:group == "Preferences", :Group_2 == "AA", :Group_3 == "Red")
	select(Not(["group", "Group_2", "Group_3", "calibration"]))
	unstack(:Group_1, :value)
	table_helper_row_group(_; row_label_var="description", overall_row_labels=levels(_.description))
	@aside @testset "table_helper_row_group 1" begin
		@test only(_.headers) == ["good" "bad"]
		@test [_.row_labels _.body][2:4,:] == ["discount factor" 0.05 0.022; "utility weight of housing" 0.5 1.0; "elasticity of substitution" 1.0 ""]
        @test _.stubhead_label == "description"
	end	
end

@chain params_df begin
	@subset(:group == "Preferences", :Group_3 == "Red")
	select(Not([:group, :calibration, :Group_3]))
	@transform!(
		@subset(:Group_2 == "BB", :Group_1 == "bad"),
		:Group_1 = "mediocre"
	)
	unstack(:Group_1, :value)
	table_helper_row_group(_; row_label_var="description", spanner_column_label_var=:Group_2, overall_row_labels=levels(_.description))
	@aside @testset "table_helper_row_group 2" begin
		@test _.spanner_column_labels == ["AA", "BB"]
		@test only(unique(_.headers)) == ["good" "bad" "mediocre"]
		@test [_.row_labels _.body][2:4,1:4] == [
			"discount factor"            0.05 0.022 "";
			"utility weight of housing"  0.5  1.0   ""; 
			"elasticity of substitution" 1.0  ""    ""]
		@test _.stubhead_label == "description"
		@test findall(.!(vcat(_.nonempty_columns...))) == [3, 5]
	end
end

end # testitem
