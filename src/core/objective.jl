################################################################################
#  Copyright 2021, Tom Van Acker                                               #
################################################################################
# StochasticPowerModels.jl                                                     #
# An extention package of PowerModels.jl for Stochastic (Optimal) Power Flow   #
# See http://github.com/timmyfaraday/StochasticPowerModels.jl                  #
################################################################################

""
function objective_min_expected_fuel_cost(pm::AbstractPowerModel; kwargs...)
    model = _PMs.check_gen_cost_models(pm)

    if model == 1 
        #return objective_min_expected_fuel_cost_pwl(pm; kwargs...)
        Memento.error(_LOGGER, "pwl cost model not supported atm.")
    elseif model == 2
        return objective_min_expected_fuel_cost_polynomial(pm; kwargs...)
    else
        Memento.error(_LOGGER, "Only cost models of types 1 and 2 are supported at this time, given cost model type of $(model)")
    end

end

""
function objective_min_expected_fuel_cost_polynomial(pm::AbstractPowerModel; kwargs...)
    mop = pm.data["mop"]
    order = _PMs.calc_max_cost_index(pm.data)-1

    if order <= 2
        return _objective_min_expected_fuel_cost_polynomial_linquad(pm, mop; kwargs...)
    else
        return _objective_min_expected_fuel_cost_polynomial_nl(pm, mop; kwargs...)
    end
end

""
function _objective_min_expected_fuel_cost_polynomial_linquad(pm::AbstractPowerModel, mop; report::Bool=true)
    gen_cost = Dict()
    
    for (g, gen) in _PMs.ref(pm, :gen)
        exp_pg = _PCE.mean([var(pm, nw, :pg, g) for nw in sorted_nw_ids(pm)], mop)        
        if length(gen["cost"]) == 1
            gen_cost[g] = gen["cost"][1]
        elseif length(gen["cost"]) == 2
            gen_cost[g] = gen["cost"][1]*exp_pg + gen["cost"][2]
        elseif length(gen["cost"]) == 3
            gen_cost[g] = gen["cost"][1]*exp_pg^2 + gen["cost"][2]*exp_pg + gen["cost"][3]
        else
            gen_cost[g] = 0.0
        end
    end

    return JuMP.@objective(pm.model, Min,
            sum(gen_cost[g] for g in _PMs.ids(pm, :gen))
    )
end

""
function _objective_min_fuel_cost_polynomial_nl(pm::AbstractPowerModel, mop; report::Bool=true)
    gen_cost = Dict()
    
    for (g, gen) in _PMs.ref(pm, :gen)
        exp_pg = _PCE.mean([var(pm, nw, :pg, g) for nw in sorted_nw_ids(pm)], mop)    

        cost_rev = reverse(gen["cost"])
        if length(cost_rev) == 1
            gen_cost[g] = JuMP.@NLexpression(pm.model, cost_rev[1])
        elseif length(cost_rev) == 2
            gen_cost[g] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*exp_pg)
        elseif length(cost_rev) == 3
            gen_cost[g] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*exp_pg + cost_rev[3]*exp_pg^2)
        elseif length(cost_rev) >= 4
            cost_rev_nl = cost_rev[4:end]
            gen_cost[g] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*exp_pg + cost_rev[3]*exp_pg^2 + sum( v*exp_pg^(d+3) for (d,v) in enumerate(cost_rev_nl)) )
        else
            gen_cost[g] = JuMP.@NLexpression(pm.model, 0.0)
        end
    end

    return JuMP.@NLobjective(pm.model, Min,
        sum(gen_cost[g] for g in _PMs.ids(pm, :gen))
    )
end