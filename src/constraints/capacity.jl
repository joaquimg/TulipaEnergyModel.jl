export add_capacity_constraints!

"""
add_capacity_constraints!(model, graph,...)

Adds the capacity constraints for all asset types to the model
"""

function add_capacity_constraints!(
    model,
    graph,
    dataframes,
    sets,
    variables,
    accumulated_initial_units,
    accumulated_investment_units_using_simple_method,
    accumulated_units,
    accumulated_units_compact_method,
    outgoing_flow_highest_out_resolution,
    incoming_flow_highest_in_resolution,
)
    ## unpack from sets
    Acv = sets[:Acv]
    Ai = sets[:Ai]
    Ap = sets[:Ap]
    As = sets[:As]
    Asb = sets[:Asb]
    V_all = sets[:V_all]
    Y = sets[:Y]
    accumulated_set_using_compact_method = sets[:accumulated_set_using_compact_method]
    accumulated_set_using_compact_method_lookup = sets[:accumulated_set_using_compact_method_lookup]
    accumulated_units_lookup = sets[:accumulated_units_lookup]
    decommissionable_assets_using_compact_method =
        sets[:decommissionable_assets_using_compact_method]
    decommissionable_assets_using_simple_method = sets[:decommissionable_assets_using_simple_method]

    ## unpack from variables
    flows_indices = variables[:flow].indices
    flow = variables[:flow].container

    ## Expressions used by capacity constraints
    # - Create capacity limit for outgoing flows
    assets_profile_times_capacity_out =
        model[:assets_profile_times_capacity_out] = [
            if row.asset ∈ decommissionable_assets_using_compact_method
                @expression(
                    model,
                    graph[row.asset].capacity * sum(
                        profile_aggregation(
                            Statistics.mean,
                            graph[row.asset].rep_periods_profiles,
                            row.year,
                            v,
                            ("availability", row.rep_period),
                            row.timesteps_block,
                            1.0,
                        ) *
                        accumulated_units_compact_method[accumulated_set_using_compact_method_lookup[(
                            row.asset,
                            row.year,
                            v,
                        )]] for v in V_all if
                        (row.asset, row.year, v) in accumulated_set_using_compact_method
                    )
                )
            else
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        row.year,
                        row.year,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) *
                    graph[row.asset].capacity *
                    accumulated_units[accumulated_units_lookup[(row.asset, row.year)]]
                )
            end for row in eachrow(dataframes[:highest_out])
        ]

    # - Create accumulated investment limit for the use of binary storage method with investments
    accumulated_investment_limit = @expression(
        model,
        accumulated_investment_limit[y in Y, a in Ai[y]∩Asb[y]],
        sum(values(graph[a].investment_limit[y]))
    )

    # - Create capacity limit for outgoing flows with binary is_charging for storage assets
    assets_profile_times_capacity_out_with_binary_part1 =
        model[:assets_profile_times_capacity_out_with_binary_part1] = [
            if row.asset ∈ Ai[row.year] && row.asset ∈ Asb[row.year]
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        row.year,
                        row.year,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) *
                    (
                        graph[row.asset].capacity * accumulated_initial_units[row.asset, row.year] +
                        accumulated_investment_limit[row.year, row.asset]
                    ) *
                    (1 - row.is_charging)
                )
            else
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        row.year,
                        row.year,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) *
                    (graph[row.asset].capacity * accumulated_initial_units[row.asset, row.year]) *
                    (1 - row.is_charging)
                )
            end for row in eachrow(dataframes[:highest_out])
        ]

    assets_profile_times_capacity_out_with_binary_part2 =
        model[:assets_profile_times_capacity_out_with_binary_part2] = [
            if row.asset ∈ Ai[row.year] && row.asset ∈ Asb[row.year]
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        row.year,
                        row.year,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) * (
                        graph[row.asset].capacity * (
                            accumulated_initial_units[row.asset, row.year] * (1 - row.is_charging) +
                            accumulated_investment_units_using_simple_method[row.asset, row.year]
                        )
                    )
                )
            end for row in eachrow(dataframes[:highest_out])
        ]

    # - Create capacity limit for incoming flows
    assets_profile_times_capacity_in =
        model[:assets_profile_times_capacity_in] = [
            @expression(
                model,
                profile_aggregation(
                    Statistics.mean,
                    graph[row.asset].rep_periods_profiles,
                    row.year,
                    row.year,
                    ("availability", row.rep_period),
                    row.timesteps_block,
                    1.0,
                ) *
                graph[row.asset].capacity *
                accumulated_units[accumulated_units_lookup[(row.asset, row.year)]]
            ) for row in eachrow(dataframes[:highest_in])
        ]

    # - Create capacity limit for incoming flows with binary is_charging for storage assets
    assets_profile_times_capacity_in_with_binary_part1 =
        model[:assets_profile_times_capacity_in_with_binary_part1] = [
            if row.asset ∈ Ai[row.year] && row.asset ∈ Asb[row.year]
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        row.year,
                        row.year,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) *
                    (
                        graph[row.asset].capacity * accumulated_initial_units[row.asset, row.year] +
                        accumulated_investment_limit[row.year, row.asset]
                    ) *
                    row.is_charging
                )
            else
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        row.year,
                        row.year,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) *
                    (graph[row.asset].capacity * accumulated_initial_units[row.asset, row.year]) *
                    row.is_charging
                )
            end for row in eachrow(dataframes[:highest_in])
        ]

    assets_profile_times_capacity_in_with_binary_part2 =
        model[:assets_profile_times_capacity_in_with_binary_part2] = [
            if row.asset ∈ Ai[row.year] && row.asset ∈ Asb[row.year]
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        row.year,
                        row.year,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) * (
                        graph[row.asset].capacity * (
                            accumulated_initial_units[row.asset, row.year] * row.is_charging +
                            accumulated_investment_units_using_simple_method[row.asset, row.year]
                        )
                    )
                )
            end for row in eachrow(dataframes[:highest_in])
        ]

    ## Capacity limit constraints (using the highest resolution)
    # - Maximum output flows limit
    model[:max_output_flows_limit] = [
        @constraint(
            model,
            outgoing_flow_highest_out_resolution[row.index] ≤
            assets_profile_times_capacity_out[row.index],
            base_name = "max_output_flows_limit[$(row.asset),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:highest_out]) if
        outgoing_flow_highest_out_resolution[row.index] != 0
    ]

    # - Maximum input flows limit
    model[:max_input_flows_limit] = [
        @constraint(
            model,
            incoming_flow_highest_in_resolution[row.index] ≤
            assets_profile_times_capacity_in[row.index],
            base_name = "max_input_flows_limit[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:highest_in]) if
        incoming_flow_highest_in_resolution[row.index] != 0
    ]

    ## Capacity limit constraints (using the highest resolution) for storage assets using binary to avoid charging and discharging at the same time
    # - Maximum output flows limit with is_charging binary for storage assets
    model[:max_output_flows_limit_with_binary_part1] = [
        @constraint(
            model,
            outgoing_flow_highest_out_resolution[row.index] ≤
            assets_profile_times_capacity_out_with_binary_part1[row.index],
            base_name = "max_output_flows_limit_with_binary_part1[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:highest_out]) if
        outgoing_flow_highest_out_resolution[row.index] != 0 &&
        row.asset ∈ Asb[row.year]
    ]

    model[:max_output_flows_limit_with_binary_part2] = [
        @constraint(
            model,
            outgoing_flow_highest_out_resolution[row.index] ≤
            assets_profile_times_capacity_out_with_binary_part2[row.index],
            base_name = "max_output_flows_limit_with_binary_part2[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:highest_out]) if
        outgoing_flow_highest_out_resolution[row.index] != 0 &&
        row.asset ∈ Ai[row.year] &&
        row.asset ∈ Asb[row.year]
    ]

    # - Maximum input flows limit with is_charging binary for storage assets
    model[:max_input_flows_limit_with_binary_part1] = [
        @constraint(
            model,
            incoming_flow_highest_in_resolution[row.index] ≤
            assets_profile_times_capacity_in_with_binary_part1[row.index],
            base_name = "max_input_flows_limit_with_binary_part1[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:highest_in]) if
        incoming_flow_highest_in_resolution[row.index] != 0 &&
        row.asset ∈ Asb[row.year]
    ]
    model[:max_input_flows_limit_with_binary_part2] = [
        @constraint(
            model,
            incoming_flow_highest_in_resolution[row.index] ≤
            assets_profile_times_capacity_in_with_binary_part2[row.index],
            base_name = "max_input_flows_limit_with_binary_part2[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:highest_in]) if
        incoming_flow_highest_in_resolution[row.index] != 0 &&
        row.asset ∈ Ai[row.year] &&
        row.asset ∈ Asb[row.year]
    ]

    # - Lower limit for flows associated with assets
    assets_with_non_negative_flows_indices = DataFrames.subset(
        flows_indices,
        [:from, :to] => DataFrames.ByRow(
            (from, to) -> from in Ap || from in Acv || from in As || to in Acv || to in As,
        ),
    )
    for row in eachrow(assets_with_non_negative_flows_indices)
        JuMP.set_lower_bound(flow[row.index], 0.0)
    end
end
