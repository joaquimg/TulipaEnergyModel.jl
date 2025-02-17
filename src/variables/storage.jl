export add_storage_variables!

"""
    add_storage_variables!(model, ...)

Adds storage-related variables to the optimization `model`, including storage levels for both intra-representative periods and inter-representative periods, as well as charging state variables.
The function also optionally sets binary constraints for certain charging variables based on storage methods.

"""
function add_storage_variables!(model, graph, sets, variables)
    storage_level_intra_rp_indices = variables[:storage_level_intra_rp].indices
    storage_level_inter_rp_indices = variables[:storage_level_inter_rp].indices
    is_charging_indices = variables[:is_charging].indices

    variables[:storage_level_intra_rp].container = [
        @variable(
            model,
            lower_bound = 0.0,
            base_name = "storage_level_intra_rp[$(row.asset),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(storage_level_intra_rp_indices)
    ]

    variables[:storage_level_inter_rp].container = [
        @variable(
            model,
            lower_bound = 0.0,
            base_name = "storage_level_inter_rp[$(row.asset),$(row.year),$(row.periods_block)]"
        ) for row in eachrow(storage_level_inter_rp_indices)
    ]

    variables[:is_charging].container = [
        @variable(
            model,
            lower_bound = 0.0,
            upper_bound = 1.0,
            base_name = "is_charging[$(row.asset),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(is_charging_indices)
    ]

    ### Binary Charging Variables
    is_charging_indices.use_binary_storage_method = [
        graph[row.asset].use_binary_storage_method[row.year] for row in eachrow(is_charging_indices)
    ]

    sub_df_is_charging_indices = DataFrames.subset(
        is_charging_indices,
        [:asset, :year] => DataFrames.ByRow((a, y) -> a in sets.Asb[y]),
        :use_binary_storage_method => DataFrames.ByRow(==("binary"));
        view = true,
    )

    for row in eachrow(sub_df_is_charging_indices)
        JuMP.set_binary(variables[:is_charging].container[row.index])
    end

    return
end
