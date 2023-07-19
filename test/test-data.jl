module TestData

export params_df, model_fit_df

using Chain
using DataFrames
using DataFrameMacros
using CategoricalArrays


df0 = DataFrame(
	description = ["average life-time", "discount factor", "utility weight of housing", "elasticity of substitution", "strength of the comparison motive", "housing supply elasticity", "depreciation rate of housing", "flow of land permits"],
	group = ["Preferences", "Preferences", "Preferences", "Preferences", "Preferences", "Technology", "Technology", "Technology"],
	calibration = ["external", "internal", "internal", "external", "internal", "external", "internal", "ad hoc"],
	AA = [45.0, 0.05, 0.5, 1.0, 0.31, 1.5, 0.052, 1.0],
	BB = [50.0, 0.07, 0.6, 0.15, 0.32, 1.0, 0.022, 1.0]
)

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

model_fit_df0 = DataFrame(
	Moment = ["Employment share", "Expenditure share", "Mortgage-to-income"],
	Target = [0.05, 0.162, 0.462],
	Source = ["Kaplan et al. (2020)", "CEX (1982)", "DINA (1980)"],
	Baseline = [0.04, 0.15, 0.45],
	Extension = [0.06, 0.17, 0.47]
)

model_fit_df = @chain model_fit_df0 begin
	stack(["Baseline", "Extension"], variable_name = "version", value_name = "Group 1")
	@transform("Group 2" = @bycol reverse({"Group 1"}))
	stack(["Group 1", "Group 2"], variable_name = :spanner)
	@transform(:row_group = :Moment == "Employment share" ? "AAA" : "BBB")
end

end