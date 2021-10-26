using Random, Distributions, DataFrames, CSV, Statistics

"""
Stores variables and state of a hydroplant element.
"""
mutable struct hidroplant
    #immutable variables
    name::String
    max_spilling::Float32            #m³/s
    min_spilling::Float32            #m³/s
    max_turbining::Float32            #m³/s
    min_turbining::Float32            #m³/s
    max_outflow::Float32            #m³/s
    min_outflow::Float32            #m³/s
    max_reservoir::Float32       #hm³
    min_reservoir::Float32       #%
    turbines_to::hidroplant
    spills_to::hidroplant
    generation_coef::Float64     #MW/m³/s
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