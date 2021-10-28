using Random, Distributions, DataFrames, CSV, Statistics, DelimitedFiles, Parameters

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
    min_reservoir_ope::Float64           #%
    generation_coef::Float64             #MW/m³/s
    turbines_to::String
    spills_to::String
    irrigation::Array{Float64, 1}        #m³/s

    #mutable variables
    spilling::Float64                    #m³/s
    turbining::Float64                   #m³/s
    reservoir::Float64                   #hm³

    #registry variables
    spill_timeline = []
    turbine_timeline = []
    reservoir_timeline = []

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
function stochastic_flow_compiler(folder_path::String,horizon::Int64 = 90)
    files = readdir(folder_path)
    names = [file_name[1:end-4] for file_name in files]
    df_std = DataFrame(Dict(name => zeros(12) for name in names))
    df_mean = DataFrame(Dict(name => zeros(12) for name in names))
    for file in files
        data = readdlm(joinpath(folder_path,file), '\t', Float64)
        for j in 1:size(data,2)
            df_std[j,file[1:end-4]] = std(data[end-horizon+1:end,j])
            df_mean[j,file[1:end-4]] = mean(data[end-horizon+1:end,j])
        end
    end
    return stochastic_flow_params(df_std,df_mean)
end

"""
Generates incremental flow for a given plant in a given month based on its statistics.
"""
function _stochastic_flow_generator(params::stochastic_flow_params,name::String15, month::Int)
    mean = params.mean[month,name]
    std = params.std[month,name]
    if mean == 0 && std == 0
        return 0.0
    end
    d = Normal(mean, std)
    td = truncated(d,0.0,Inf)
    return rand(td)
end

"""
Generates incremental flows for all plants along entire simulation.
"""
function loads_stochastic_incremental_flows(params::stochastic_flow_params, hidroplants::Dict, timesteps::Int64)
    flows = Dict()
    for name in keys(hidroplants)
        flows[name] = []
        for step in 1:timesteps
            push!(flows[name], _stochastic_flow_generator(params, name, step == 12 ? 12 : mod(step, 12)))
        end
    end
    return flows
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
            min_reservoir_ope = df[i,"min_reservoir_ope"],
            generation_coef = df[i,"generation_coef"],
            turbines_to = df[i,"turbines_to"],
            spills_to = df[i,"spills_to"],
            irrigation = irrigation,
            spilling = df[i,"min_spilling"],
            turbining = df[i,"min_turbining"],
            reservoir = volume
        )
    end
    return hidroplants
end

function gets_turbine_from(name::String, hidroplants::Dict)
    result = []
    for (key, hidroplant) in hidroplants
        if hidroplant.turbines_to == name
            push!(result, key)
        end
    end
    return result
end

function gets_spill_from(name::String, hidroplants::Dict)
    result = []
    for (key, hidroplant) in hidroplants
        if hidroplant.spills_to == name
            push!(result, key)
        end
    end
    return result
end

function get_outflow(hidroplant::Type{hidroplant})
    return hidroplant.spilling + hidroplant.turbining
end