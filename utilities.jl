using Random, Distributions, DataFrames, CSV, Statistics, DelimitedFiles

"""
Stores variables and state of a hydroplant element.
"""
mutable struct hidroplant

    #immutable variables
    name::String
    max_spilling::Float64                #m³/s
    min_spilling::Float64                #m³/s
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
    turbine_spill_ratio::Float64
    irrigation::Array{Float64, 1}
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
Generates normal random values for flows based on its statistics.
"""
function stochastic_flow_generator(params::stochastic_flow_params,name::String, month::Int)
    mean = params.mean[month,name]
    std = params.std[month,name]
    d = Normal(mean, std)
    td = truncated(d,0.0,Inf)
    return rand(td)
end

function loads_hidroplants(file_path::String)
    df = DataFrame(CSV.File(file_path))
    @show df
    hidroplants = Dict()
    for i in 1:size(df,1)
        name = df[i,"name"]
        if name in [name[1:end-4] for name in readdir("irrigation_data")]
            irrigation = vec(readdlm(joinpath("irrigation_data",name*".csv"), '\t', Float64))
        else
            irrigation = zeros(12)
        end
        hidroplants[name] = hidroplant(
            name,
            df[i,"max_spillage"],
            df[i,"min_spillage"],
            df[i,"max_turbining"],
            df[i,"min_turbining"],
            df[i,"max_outflow"],
            df[i,"min_outflow"],
            df[i,"max_reservoir"],
            df[i,"min_reservoir"],
            df[i,"min_reservoir_ope"],
            df[i,"generation_coef"],
            df[i,"turbines_to"],
            df[i,"spills_to"],
            1.0,
            irrigation
        )
    end
    return hidroplants
end

loads_hidroplants("hidroplants_params.csv")