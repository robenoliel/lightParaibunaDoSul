using Random, Distributions, DataFrames, CSV, Statistics, DelimitedFiles, Parameters, Dates, Polynomials

"""
Stores variables and state of a hydroplant element.
"""
@with_kw mutable struct hidroplant

    #immutable variables
    name::String
    max_spillage::Float64                #m³/s
    min_spillage::Float64                #m³/s
    max_turbining::Float64               #m³/s
    min_turbining::Float64               #m³/s
    max_outflow::Float64                 #m³/s
    min_outflow::Float64                 #m³/s
    max_reservoir::Float64               #hm³
    min_reservoir::Float64               #hm³
    min_reservoir_ope_per::Float64        #%
    generation_coef::Float64             #MW/m³/s
    turbines_to::String
    spills_to::String
    irrigation::Array{Float64, 1}        #m³/s
    evaporation_coef::Array{Float64, 1}  #mm/month
    poly_volume_quote::Union{String,Array{Float64, 1}}
    poly_quote_area::Union{String,Array{Float64, 1}}
    area::Float64                        #km²

    min_reservoir_ope = min_reservoir + min_reservoir_ope_per*(max_reservoir - min_reservoir) #hm³

    #mutable variables
    spilling::Float64                    #m³/s
    turbining::Float64                   #m³/s
    reservoir::Float64                   #hm³
    inflow::Float64 = 0.0                #hm³
    evaporation::Float64 = 0.0                #hm³

    #registry variables
    spill_timeline = []                  #m³/s
    turbine_timeline = []                #m³/s
    reservoir_timeline = []              #hm³
    inflow_timeline = []                 #hm³
    evaporation_timeline = []            #hm³

end

"""
Stores statistical data about flows for later stochastic generation of random values.
"""
struct stochastic_flow_params
    std::DataFrame
    mean::DataFrame
end

"""
Reads flow time series and generates statistical data about flows for later stochastic generation of random values.
"""
function flow_compiler(folder_path::String,horizon::Int64 = 90)
    files = readdir(folder_path)
    names = [file_name[1:end-4] for file_name in files]
    df_topology = DataFrame(CSV.File("topology.csv"))
    df_flows = Dict()
    """
    df_std = DataFrame(Dict(name => zeros(12) for name in names))
    df_mean = DataFrame(Dict(name => zeros(12) for name in names))
    """
    for file in files
        name = file[1:end-4]
        data = readdlm(joinpath(folder_path,file), '\t', Float64)
        for i in 1:size(df_topology, 1)
            if df_topology[i,"downstream"] == name
                plant = df_topology[i,"plant"]
                upstream = readdlm(joinpath(folder_path,plant*".csv"), '\t', Float64)
                data -= upstream
            end
        end
        """
        for j in 1:size(data,2)
            df_std[j,file[1:end-4]] = std(data[end-horizon+1:end,j])
            df_mean[j,file[1:end-4]] = mean(data[end-horizon+1:end,j])
        end
        """
        df_flows[name] = reshape(data',(1,1080))[end-12*horizon+1:end]
    end

    return df_flows
end

"""
Loads hidroplants parameters from files to structs. Returns dictionary of `hidroplant`.
"""
function loads_hidroplants(file_path::String; reservoir_start::String = "min")
    df = DataFrame(CSV.File(file_path))
    hidroplants = Dict()
    for i in 1:size(df,1)
        name = df[i,"name"]
        if name in [name[1:end-4] for name in readdir("irrigation_data")]
            irrigation = vec(readdlm(joinpath("irrigation_data",name*".csv"), '\t', Float64))
        else
            irrigation = zeros(12)
        end
        if name in [name[1:end-4] for name in readdir(joinpath("evaporation_data","coefficients"))]
            evaporation_coef = vec(readdlm(joinpath("evaporation_data","coefficients",name*".csv"), '\t', Float64))
            if name in [name[1:end-4] for name in readdir(joinpath("evaporation_data","polynomials"))]
                polynomials = readdlm(joinpath("evaporation_data","polynomials",name*".csv"), '\t', Float64)
                poly_volume_quote = vec(polynomials[1,:])
                poly_quote_area = vec(polynomials[2,:])
            else
                poly_volume_quote = "nothing"
                poly_quote_area = "nothing"
            end
        else
            evaporation_coef = zeros(12)
            poly_volume_quote = "nothing"
            poly_quote_area = "nothing"
        end
        if reservoir_start == "max"
            volume = df[i,"max_reservoir"]
        elseif reservoir_start == "mean"
            volume = (df[i,"max_reservoir"] + df[i,"min_reservoir"] + df[i,"min_reservoir_ope"]*(df[i,"max_reservoir"] - df[i,"min_reservoir"]))/2
        elseif reservoir_start == "min"
            volume = df[i,"min_reservoir"] + df[i,"min_reservoir_ope"]*(df[i,"max_reservoir"] - df[i,"min_reservoir"])
        end
        hidroplants[name] = hidroplant(
            name = name,
            max_spillage = df[i,"max_spillage"],
            min_spillage = df[i,"min_spillage"],
            max_turbining = df[i,"max_turbining"],
            min_turbining = df[i,"min_turbining"],
            max_outflow = df[i,"max_outflow"],
            min_outflow = df[i,"min_outflow"],
            max_reservoir = df[i,"max_reservoir"],
            min_reservoir = df[i,"min_reservoir"],
            min_reservoir_ope_per = df[i,"min_reservoir_ope"],
            generation_coef = df[i,"generation_coef"],
            turbines_to = df[i,"turbines_to"],
            spills_to = df[i,"spills_to"],
            irrigation = irrigation,
            spilling = df[i,"min_spillage"],
            turbining = df[i,"min_turbining"],
            reservoir = volume,
            evaporation_coef = evaporation_coef,
            poly_volume_quote = poly_volume_quote,
            poly_quote_area = poly_quote_area,
            area = df[i,"area"]
        )
    end
    return hidroplants
end

"""
Will balance every plant's reservoir for next timestep and update its registries.
"""
function updates_registries(hidroplants::Dict, incremental_natural_flows::Dict,step::Int64)
    for (_, plant) in hidroplants
        push!(plant.spill_timeline, plant.spilling)
        push!(plant.turbine_timeline, plant.turbining)
        push!(plant.reservoir_timeline, plant.reservoir)
        push!(plant.inflow_timeline, plant.inflow)
        push!(plant.evaporation_timeline, plant.evaporation)
    end
end

"""
Updates plant reservoir based on its parameters at a time step.
"""
function hidro_balance(name::Union{String,String15},hidroplants::Dict,step::Int64)
    plant = hidroplants[name]
    month = mod(step, 12) == 0 ? 12 : mod(step, 12)
    gain = plant.reservoir + plant.inflow
    lost = m3_per_sec_to_hm3_per_month(plant.turbining, month)
    lost += m3_per_sec_to_hm3_per_month(plant.spilling, month)
    #lost += plant.evaporation[month]
    plant.reservoir = gain - lost
end

"""
Updates inflow of plant considering activity of elements before it.
"""
function updates_inflow(name::Union{String,String15}, hidroplants::Dict, incremental_natural_flows::Dict, step::Int64)
    month = mod(step, 12) == 0 ? 12 : mod(step, 12)
    incremental_flow = m3_per_sec_to_hm3_per_month(incremental_natural_flows[name][step],month)
    turbine_names = _gets_turbine_from(name, hidroplants)
    for turbine_name in turbine_names
        incremental_flow += m3_per_sec_to_hm3_per_month(hidroplants[turbine_name].turbining, month)
    end
    spillage_names = _gets_spillage_from(name, hidroplants)
    for spillage_name in spillage_names
        incremental_flow += m3_per_sec_to_hm3_per_month(hidroplants[spillage_name].spilling, month)
    end
    if hidroplants[name].poly_volume_quote != "nothing"
        hidroplants[name].evaporation =  hidroplants[name].area *  hidroplants[name].evaporation_coef[month]/1000
        pvq = Polynomial(hidroplants[name].poly_volume_quote)
        pqa = Polynomial(hidroplants[name].poly_quote_area)
        q = pvq(hidroplants[name].reservoir)
        hidroplants[name].area = pqa(q)
    end
    hidroplants[name].evaporation =  hidroplants[name].area *  hidroplants[name].evaporation_coef[month]/1000
    incremental_flow -= hidroplants[name].evaporation
    incremental_flow -= m3_per_sec_to_hm3_per_month(hidroplants[name].irrigation[month], month)
    hidroplants[name].inflow = incremental_flow
end

"""
Maps how much a plant will turbine depending on its reservoir and limits.
"""
function calculates_turbine(name::Union{String15,String},hidroplants::Dict,n::Int64)
    plant = hidroplants[name]
    n = 2*n - 1
    avg_reservoir = (plant.max_reservoir + plant.min_reservoir_ope)/2
    x = (plant.reservoir - avg_reservoir)/(avg_reservoir - plant.min_reservoir)
    value = (sign(x)*(abs(x)^(1/n)) + 1)*(plant.max_turbining - plant.min_turbining)/2
    if value > plant.max_turbining
        return plant.max_turbining
    elseif value < plant.min_turbining
        return plant.min_turbining
    else
        return value
    end
end

"""
Calculates % of equivalent reservoir.
"""
function paraibuna_do_sul_equivalent_reservoir_status(hidroplants::Dict)
    equiv_max = 0
    equiv_min = 0
    equiv_current = 0
    for name in ["funil","sta_cecilia","sta_branca","jaguari","paraibuna"]
        equiv_max += hidroplants[name].max_reservoir
        equiv_min += hidroplants[name].min_reservoir
        equiv_current += hidroplants[name].reservoir
    end
    return (equiv_current - equiv_min)/(equiv_max - equiv_min)
end

"""
Calculates % of equivalent reservoir.
"""
function reservoir_status(name::Union{String15,String},hidroplants::Dict)
    plant = hidroplants[name]
    return (plant.reservoir - plant.min_reservoir)/(plant.max_reservoir - plant.min_reservoir)
end

"""
Finds which plant turbines to a given one.
"""
function _gets_turbine_from(name::Union{String,String15}, hidroplants::Dict)
    result = []
    for (key, hidroplant) in hidroplants
        if hidroplant.turbines_to == name
            push!(result, key)
        end
    end
    return result
end

"""
Finds which plant spills to a given one.
"""
function _gets_spillage_from(name::Union{String,String15}, hidroplants::Dict)
    result = []
    for (key, hidroplant) in hidroplants
        if hidroplant.spills_to == name
            push!(result, key)
        end
    end
    return result
end

"""
Converts from m³/s to hm³/month.
"""
function m3_per_sec_to_hm3_per_month(value::Float64,month::Int64)
    t = Date(2020,month,1)
    return value*60*60*24*daysinmonth(t)/10^6
end

"""
Converts from hm³/month to m³/s.
"""
function hm3_per_month_to_m3_per_sec(value::Float64,month::Int64)
    t = Date(2020,month,1)
    return value*10^6/(60*60*24*daysinmonth(t))
end

"""
Operates run-of-river plant at a given step of the simulation.
"""
function operate_run_of_river_plant(name::Union{String15,String},hidroplants::Dict,incremental_natural_flows::Dict,step::Int64)
    month = mod(step, 12) == 0 ? 12 : mod(step, 12)
    updates_inflow(name, hidroplants, incremental_natural_flows, step)
    if hidroplants[name].inflow >= m3_per_sec_to_hm3_per_month(hidroplants[name].min_turbining, month) + m3_per_sec_to_hm3_per_month(hidroplants[name].min_spillage, month)
        available = hm3_per_month_to_m3_per_sec(hidroplants[name].inflow,month)
        if available >= hidroplants[name].max_turbining
            available_spill = available - hidroplants[name].max_turbining
            if available_spill >= hidroplants[name].min_spillage
                hidroplants[name].turbining = hidroplants[name].max_turbining
                hidroplants[name].spilling = available_spill
            else
                hidroplants[name].turbining = available - hidroplants[name].min_spillage
                hidroplants[name].spilling = hidroplants[name].min_spillage
            end
        else
            hidroplants[name].turbining = available - hidroplants[name].min_spillage
            hidroplants[name].spilling = hidroplants[name].min_spillage
        end
    else
        available = hm3_per_month_to_m3_per_sec(hidroplants[name].inflow, month) - hidroplants[name].min_turbining
        if available > 0
            hidroplants[name].turbining = hidroplants[name].min_turbining
            hidroplants[name].spilling = available - hidroplants[name].min_turbining
        else
            hidroplants[name].turbining = hm3_per_month_to_m3_per_sec(hidroplants[name].inflow, month)
            hidroplants[name].spilling = 0.0
        end
    end
    hidro_balance(name,hidroplants,step)
end

"""
Operates reservoir plant at a given step of the simulation.
"""
function operate_reservoir_plant(name::Union{String15,String},hidroplants::Dict,incremental_natural_flows::Dict,step::Int64)
    month = mod(step, 12) == 0 ? 12 : mod(step, 12)
    updates_inflow(name, hidroplants, incremental_natural_flows, step)
    final_reservoir = hidroplants[name].reservoir + hidroplants[name].inflow - m3_per_sec_to_hm3_per_month(hidroplants[name].min_turbining, month) - m3_per_sec_to_hm3_per_month(hidroplants[name].min_spillage, month)
    eighty_reservoir = 0.8*(hidroplants[name].max_reservoir - hidroplants[name].min_reservoir) + hidroplants[name].min_reservoir
    if name in ["sta_branca","jaguari","paraibuna","funil"] && paraibuna_do_sul_equivalent_reservoir_status(hidroplants) > 0.8 && reservoir_status(name,hidroplants) > 0.8 && final_reservoir > eighty_reservoir
        excess_reservoir = final_reservoir - eighty_reservoir
        if hidroplants[name].min_turbining + hm3_per_month_to_m3_per_sec(excess_reservoir, month) <= hidroplants[name].max_turbining
            hidroplants[name].turbining = hidroplants[name].min_turbining + hm3_per_month_to_m3_per_sec(excess_reservoir, month)
            hidroplants[name].spilling = hidroplants[name].min_spillage
        else
            excess_turbining = hidroplants[name].min_turbining + hm3_per_month_to_m3_per_sec(excess_reservoir, month) - hidroplants[name].max_turbining
            hidroplants[name].turbining = hidroplants[name].max_turbining
            hidroplants[name].spilling = excess_turbining
        end
    elseif final_reservoir > hidroplants[name].max_reservoir
        excess_reservoir = final_reservoir - hidroplants[name].max_reservoir
        if hidroplants[name].min_turbining + hm3_per_month_to_m3_per_sec(excess_reservoir, month) <= hidroplants[name].max_turbining
            hidroplants[name].turbining = hidroplants[name].min_turbining + hm3_per_month_to_m3_per_sec(excess_reservoir, month)
            hidroplants[name].spilling = hidroplants[name].min_spillage
        else
            excess_turbining = hidroplants[name].min_turbining + hm3_per_month_to_m3_per_sec(excess_reservoir, month) - hidroplants[name].max_turbining
            hidroplants[name].turbining = hidroplants[name].max_turbining
            hidroplants[name].spilling = excess_turbining
        end
    elseif final_reservoir < hidroplants[name].min_reservoir_ope
        if name in ["sta_branca","funil"]
            extra = ask_previous_plants(name, hidroplants, hidroplants[name].min_reservoir_ope - final_reservoir,month)
            hidroplants[name].inflow += extra
            final_reservoir = hidroplants[name].reservoir + hidroplants[name].inflow - m3_per_sec_to_hm3_per_month(hidroplants[name].min_turbining, month) - m3_per_sec_to_hm3_per_month(hidroplants[name].min_spillage, month)
        end
        if final_reservoir*(1-0.0001) <= hidroplants[name].min_reservoir_ope
            if hidroplants[name].reservoir + hidroplants[name].inflow - hidroplants[name].min_reservoir_ope >= 0
                hidroplants[name].turbining = hm3_per_month_to_m3_per_sec(hidroplants[name].reservoir + hidroplants[name].inflow - hidroplants[name].min_reservoir_ope,month)
                hidroplants[name].spilling = 0
            else
                hidroplants[name].turbining = 0
                hidroplants[name].spilling = 0
            end
        end
    else
        hidroplants[name].turbining = hidroplants[name].min_turbining
        hidroplants[name].spilling = hidroplants[name].min_spillage
    end
    hidro_balance(name,hidroplants,step)
end

"""
Manages how, if conditions allow to, previous plants may send more water to those which are not fullfilling
their minimum requirements.
"""
function ask_previous_plants(name::Union{String15,String},hidroplants::Dict,value::Float64,month::Int64)
    paraibuna_do_sul_depletion_update(hidroplants,month)
    extra_acquired = 0.0
    if name == "funil"
        previous_ones = ["sta_branca","jaguari"]
    else
        previous_ones = _gets_turbine_from(name,hidroplants)
    end
    if previous_ones == []
        return 0.0
    end
    lacking = 0.0
    for previous in previous_ones
        value -= extra_acquired
        if hidroplants[previous].reservoir - value > hidroplants[previous].min_reservoir_ope
            if hidroplants[previous].turbining + hm3_per_month_to_m3_per_sec(value,month) < hidroplants[previous].max_turbining
                hidroplants[previous].turbining += hm3_per_month_to_m3_per_sec(value,month)
            else
                can_turbinate = hidroplants[previous].max_turbining - hidroplants[previous].turbining
                hidroplants[previous].turbining += can_turbinate
                hidroplants[previous].spilling += hm3_per_month_to_m3_per_sec(value,month) - can_turbinate
            end
            hidroplants[previous].reservoir -= value
            extra_acquired += value
            return extra_acquired
        else
            available = hidroplants[previous].reservoir - hidroplants[previous].min_reservoir_ope > 0 ? hidroplants[previous].reservoir - hidroplants[previous].min_reservoir_ope : 0.0
            lacking = value - available
            if hidroplants[previous].turbining + hm3_per_month_to_m3_per_sec(available,month) < hidroplants[previous].max_turbining
                hidroplants[previous].turbining += hm3_per_month_to_m3_per_sec(available,month)
            else
                can_turbinate = hidroplants[previous].max_turbining - hidroplants[previous].turbining
                hidroplants[previous].turbining += can_turbinate
                hidroplants[previous].spilling += hm3_per_month_to_m3_per_sec(available,month) - can_turbinate
            end
            hidroplants[previous].reservoir -= available
            extra_acquired = available + ask_previous_plants(previous,hidroplants,lacking,month)
            if extra_acquired >= value
                return extra_acquired
            end
        end
    end
    return extra_acquired
end

"""
Operates Santa Cecilia plant.
"""
function operates_sta_cecilia_plant(hidroplants::Dict,incremental_natural_flows::Dict,step::Int64)
    min_reservoir_ope = hidroplants["sta_cecilia"].min_reservoir_ope
    max_reservoir = hidroplants["sta_cecilia"].max_reservoir
    min_spillage = hidroplants["sta_cecilia"].min_spillage
    max_spillage = hidroplants["sta_cecilia"].max_spillage
    min_turbining = hidroplants["sta_cecilia"].min_turbining
    max_turbining = hidroplants["sta_cecilia"].max_turbining
    reservoir =  hidroplants["sta_cecilia"].reservoir
    updates_inflow("sta_cecilia", hidroplants, incremental_natural_flows, step)
    inflow =  hidroplants["sta_cecilia"].inflow
    month = mod(step, 12) == 0 ? 12 : mod(step, 12)
    excess = hm3_per_month_to_m3_per_sec(reservoir,month) + hm3_per_month_to_m3_per_sec(inflow,month) - min_spillage - min_turbining - hm3_per_month_to_m3_per_sec(max_reservoir,month)
    
    if excess < 0
        extra = ask_previous_plants("sta_cecilia",hidroplants,m3_per_sec_to_hm3_per_month((-1)*excess,month),month)
        hidroplants["sta_cecilia"].inflow += extra
    end
    inflow =  hidroplants["sta_cecilia"].inflow
    if excess >= 0
        if excess <= max_spillage - min_spillage
            hidroplants["sta_cecilia"].spilling = excess + min_spillage
            hidroplants["sta_cecilia"].turbining = min_turbining
        elseif excess <= max_spillage - min_spillage + max_turbining - min_turbining
            hidroplants["sta_cecilia"].spilling = max_spillage
            hidroplants["sta_cecilia"].turbining = excess + min_turbining - (max_spillage - min_spillage)
        else
            hidroplants["sta_cecilia"].spilling = excess + min_spillage + min_turbining - max_turbining
            hidroplants["sta_cecilia"].turbining = max_turbining
        end
    elseif reservoir + inflow - m3_per_sec_to_hm3_per_month(min_spillage,month) -  m3_per_sec_to_hm3_per_month(min_turbining,month) >= min_reservoir_ope
        hidroplants["sta_cecilia"].spilling = min_spillage
        hidroplants["sta_cecilia"].turbining = min_turbining
    elseif reservoir + inflow - m3_per_sec_to_hm3_per_month(min_spillage,month) >= min_reservoir_ope
        hidroplants["sta_cecilia"].spilling = min_spillage
        hidroplants["sta_cecilia"].turbining = hm3_per_month_to_m3_per_sec(reservoir + inflow - min_reservoir_ope, month) - min_spillage
    else
        hidroplants["sta_cecilia"].spilling = hm3_per_month_to_m3_per_sec(reservoir + inflow - min_reservoir_ope, month)
        hidroplants["sta_cecilia"].turbining = 0
    end
    hidro_balance("sta_cecilia",hidroplants,step)
end

"""
Update Paraibuna do Sul depletion status according to ANA resolution.
"""
function paraibuna_do_sul_depletion_update(hidroplants::Dict,month::Int64)
    wait_vol = [658.403, 698.333, 788.175, 888, 888, 888, 888, 888, 888, 888, 748.245, 618.473]
    hidroplants["funil"].max_reservoir = wait_vol[month]
    stage = 1
    hidroplants["funil"].min_reservoir_ope = 0.3*(hidroplants["funil"].max_reservoir - hidroplants["funil"].min_reservoir) + hidroplants["funil"].min_reservoir
    hidroplants["sta_branca"].min_reservoir_ope = 0.7*(hidroplants["sta_branca"].max_reservoir - hidroplants["sta_branca"].min_reservoir) + hidroplants["sta_branca"].min_reservoir
    hidroplants["paraibuna"].min_reservoir_ope = 0.8*(hidroplants["paraibuna"].max_reservoir - hidroplants["paraibuna"].min_reservoir) + hidroplants["paraibuna"].min_reservoir
    hidroplants["jaguari"].min_reservoir_ope = 0.8*(hidroplants["jaguari"].max_reservoir - hidroplants["jaguari"].min_reservoir) + hidroplants["jaguari"].min_reservoir
    if 0.3*(1+0.05) >= reservoir_status("funil",hidroplants) && 0.7*(1+0.05) >= reservoir_status("sta_branca",hidroplants) && 0.8*(1+0.05) >= reservoir_status("paraibuna",hidroplants) && 0.8*(1+0.05) >= reservoir_status("jaguari",hidroplants)
        stage = 2
        hidroplants["sta_branca"].min_reservoir_ope = 0.4*(hidroplants["sta_branca"].max_reservoir - hidroplants["sta_branca"].min_reservoir) + hidroplants["sta_branca"].min_reservoir
        if 0.4*(1+0.05) >= reservoir_status("sta_branca",hidroplants)
            hidroplants["paraibuna"].min_reservoir_ope = 0.4*(hidroplants["paraibuna"].max_reservoir - hidroplants["paraibuna"].min_reservoir) + hidroplants["paraibuna"].min_reservoir
            if 0.4*(1+0.05) >= reservoir_status("paraibuna",hidroplants)
                hidroplants["jaguari"].min_reservoir_ope = 0.5*(hidroplants["jaguari"].max_reservoir - hidroplants["jaguari"].min_reservoir) + hidroplants["jaguari"].min_reservoir
                if 0.5*(1+0.05) >= reservoir_status("jaguari",hidroplants)
                    stage = 3
                    hidroplants["sta_branca"].min_reservoir_ope = 0.1*(hidroplants["sta_branca"].max_reservoir - hidroplants["sta_branca"].min_reservoir) + hidroplants["sta_branca"].min_reservoir
                    if 0.1*(1+0.05) >= reservoir_status("sta_branca",hidroplants)
                        hidroplants["paraibuna"].min_reservoir_ope = 0.05*(hidroplants["paraibuna"].max_reservoir - hidroplants["paraibuna"].min_reservoir) + hidroplants["paraibuna"].min_reservoir
                        if 0.05*(1+0.05) >= reservoir_status("paraibuna",hidroplants)
                            hidroplants["jaguari"].min_reservoir_ope = 0.2*(hidroplants["jaguari"].max_reservoir - hidroplants["jaguari"].min_reservoir) + hidroplants["jaguari"].min_reservoir
                            if 0.2*(1+0.05) >= reservoir_status("jaguari",hidroplants)
                                stage = 4
                                hidroplants["paraibuna"].min_reservoir_ope = 0.2*(hidroplants["paraibuna"].max_reservoir - hidroplants["paraibuna"].min_reservoir) + hidroplants["paraibuna"].min_reservoir - 425
                            end
                        end
                    end
                end
            end
        end
    end
    return stage
end

"""
function _stochastic_flow_generator(params::stochastic_flow_params,name::String15, month::Int, bias::Float64)
    mean = params.mean[month,name]
    std = params.std[month,name]
    if mean == 0 && std == 0
        return 0.0
    end
    d = Normal(mean + bias*std, std)
    td = truncated(d,0.0,Inf)
    return m3_per_sec_to_hm3_per_month(rand(td),month)
end

function loads_stochastic_incremental_flows(params::stochastic_flow_params, hidroplants::Dict, timesteps::Int64, bias::Float64)
    flows = Dict()
    for name in keys(hidroplants)
        flows[name] = []
        for step in 1:timesteps
            month = mod(step, 12) == 0 ? 12 : mod(step, 12)
            push!(flows[name], _stochastic_flow_generator(params, name, month, bias))
        end
    end
    return flows
end
"""