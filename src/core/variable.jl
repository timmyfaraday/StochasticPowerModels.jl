################################################################################
#  Copyright 2021, Tom Van Acker                                               #
################################################################################
# StochasticPowerModels.jl                                                     #
# An extention package of PowerModels.jl for Stochastic (Optimal) Power Flow   #
# See http://github.com/timmyfaraday/StochasticPowerModels.jl                  #
################################################################################

"variable: `vs[i]` for `i` in `bus`es"
function variable_bus_voltage_squared(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    vs = var(pm, nw)[:vs] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :bus)], base_name="$(nw)_vs",
        start = comp_start_value(ref(pm, nw, :bus, i), "vs_start", 1.0)
    )

    if bounded
        for (i, bus) in ref(pm, nw, :bus)
            JuMP.set_lower_bound(vs[i], bus["vmin"]^2)
            JuMP.set_upper_bound(vs[i], bus["vmax"]^2)
        end
    end

    report && sol_component_value(pm, nw, :bus, :vs, ids(pm, nw, :bus), vs)
end

"variable: `crd[j]` for `j` in `load`"
function variable_load_current_real(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    crd = var(pm, nw)[:crd] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :load)], base_name="$(nw)_crd",
        start = comp_start_value(ref(pm, nw, :load, i), "crd_start")
    )

    if bounded
        bus = ref(pm, nw, :bus)
        for (i, l) in ref(pm, nw, :load)
            vmin = bus[l["load_bus"]]["vmin"]
            @assert vmin > 0
            s = sqrt(max(abs(l["pmax"]), abs(l["pmin"]))^2 + max(abs(l["qmax"]), abs(l["qmin"]))^2)
            ub = s/vmin

            JuMP.set_lower_bound(crd[i], -ub)
            JuMP.set_upper_bound(crd[i],  ub)
        end
    end

    report && sol_component_value(pm, nw, :load, :crd, ids(pm, nw, :load), crd)
end

"variable: `cid[j]` for `j` in `load`"
function variable_load_current_imaginary(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    cid = var(pm, nw)[:cid] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :load)], base_name="$(nw)_cid",
        start = comp_start_value(ref(pm, nw, :load, i), "cid_start")
    )

    if bounded
        bus = ref(pm, nw, :bus)
        for (i, l) in ref(pm, nw, :load)
            vmin = bus[l["load_bus"]]["vmin"]
            @assert vmin > 0
            s = sqrt(max(abs(l["pmax"]), abs(l["pmin"]))^2 + max(abs(l["qmax"]), abs(l["qmin"]))^2)
            ub = s/vmin

            JuMP.set_lower_bound(cid[i], -ub)
            JuMP.set_upper_bound(cid[i],  ub)
        end
    end

    report && sol_component_value(pm, nw, :load, :cid, ids(pm, nw, :load), cid)
end

"variable: `css[l,i,j]` for `(l,i,j)` in `arcs_from`"
function variable_branch_series_current_squared(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    css = var(pm, nw)[:css] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :branch)], base_name="$(nw)_css",
        start = comp_start_value(ref(pm, nw, :branch, l), "css_start", 0.0)
    )

    if bounded
        bus = ref(pm, nw, :bus)
        branch = ref(pm, nw, :branch)

        for (l,i,j) in ref(pm, nw, :arcs_from)
            b = branch[l]
            ub = Inf
            if haskey(b, "rate_a")
                rate = b["rate_a"]*b["tap"]
                y_fr = abs(b["g_fr"] + im*b["b_fr"])
                y_to = abs(b["g_to"] + im*b["b_to"])
                shunt_current = max(y_fr*bus[i]["vmax"]^2, y_to*bus[j]["vmax"]^2)
                series_current = max(rate/bus[i]["vmin"], rate/bus[j]["vmin"])
                ub = series_current + shunt_current
            end
            if haskey(b, "c_rating_a")
                total_current = b["c_rating_a"]
                y_fr = abs(b["g_fr"] + im*b["b_fr"])
                y_to = abs(b["g_to"] + im*b["b_to"])
                shunt_current = max(y_fr*bus[i]["vmax"]^2, y_to*bus[j]["vmax"]^2)
                ub = total_current + shunt_current
            end

            if !isinf(ub)
                JuMP.set_lower_bound(css[l],  0.0)
                JuMP.set_upper_bound(css[l],  ub^2)
            end
        end
    end

    report && sol_component_value(pm, nw, :branch, :css, ids(pm, nw, :branch), css)
end