using Random, Distributions, DataFrames, CSV, Statistics, DelimitedFiles, Parameters, Dates, Polynomials, GLM

"""
    run_simulation(case_name::String;verbose::Bool = true)

Runs a simulation of Paraiba do Sul and pre determined associated plants. Arguments:
* `case_name`: Project name, folder with input data must be called like this.
* `verbose`: If to display simulation progress.
"""
function run_simulation(case_name::String;verbose::Bool = true)
    filling_mode = 1
    eighty_policiy = true

    if !isdir(case_name)
        throw(SystemError("The $(case_name) folder is missing. Check its spelling or specify a different folder."))
    end

    for folder in ["evaporation_data","flow_data","generation_data","irrigation_data"]
        if !isdir(joinpath(case_name,folder))
            throw(SystemError("The $(folder) folder is missing. Make sure to include it under the right format."))
        end
    end

    for file in ["hidroplants_params.csv","topology.csv"]
        if !isfile(joinpath(case_name,file))
            throw(SystemError("The $(file) file is missing. Make sure to include it under the right format."))
        end
    end

    if verbose println("########### Simulation Start ###########") end
    #loads incremental flows for simulation
    hidroplants = loads_hidroplants(case_name)
    incremental_natural_flows = flow_compiler(joinpath(case_name),hidroplants)
    timesteps = size(incremental_natural_flows["funil"],1)
    years = Int64(trunc(timesteps/12))

    depletion_stages = []
    equivalent_reservoir = []
    months = []
    stage = 1

    for step in 1:timesteps
        month = mod(step, 12) == 0 ? 12 : mod(step, 12)
        push!(months,month)
    
        #Tocos operation: to keep reservoir at same volume, will turbine all it's incremental flow, and spill what's beyond its turbination limit.
        operate_run_of_river_plant("tocos",hidroplants,incremental_natural_flows,step)
        
        #Lajes operation
        operate_reservoir_plant("lajes",hidroplants,incremental_natural_flows,step)
    
        #Fontes_a operation: to keep reservoir at same volume, will turbine all it's incremental flow, and spill what's beyond its turbination limit.
        operate_run_of_river_plant("fontes_a",hidroplants,incremental_natural_flows,step)
        
        #Picada operation
        operate_run_of_river_plant("picada",hidroplants,incremental_natural_flows,step)
    
        #Sobragi operation
        operate_run_of_river_plant("sobragi",hidroplants,incremental_natural_flows,step)
    
        #Updates depletion status
        stage = paraibuna_do_sul_depletion_update(hidroplants,month,stage,filling_mode)
        
        #Jaguari operation
        operate_reservoir_plant("jaguari",hidroplants,incremental_natural_flows,step)
    
        #Paraibuna operation
        operate_reservoir_plant("paraibuna",hidroplants,incremental_natural_flows,step)
    
        #Sta Branca operation
    
        operate_reservoir_plant("sta_branca",hidroplants,incremental_natural_flows,step)
        
    
        #Funil operation
        operate_reservoir_plant("funil",hidroplants,incremental_natural_flows,step)
    
        #Santa Cecilia operation
    
        operates_sta_cecilia_plant(hidroplants,incremental_natural_flows,step,stage,filling_mode,eighty_policiy)
    
        #Santana operation
        operate_run_of_river_plant("santana",hidroplants,incremental_natural_flows,step)
    
        
        #Simplicio operation
        operate_run_of_river_plant("simplicio",hidroplants,incremental_natural_flows,step)
    
        #Ilha dos Pombos operation
        operate_run_of_river_plant("ilha_dos_pombos",hidroplants,incremental_natural_flows,step)
        
        #Vigario operation
        operate_run_of_river_plant("vigario",hidroplants,incremental_natural_flows,step)
    
        #Nilo Peçanha operation
        operate_run_of_river_plant("nilo_pecanha",hidroplants,incremental_natural_flows,step)
    
        #Fontes BC operation
        operate_run_of_river_plant("fontes_bc",hidroplants,incremental_natural_flows,step)
    
        #Pereira Passos operation
        operate_run_of_river_plant("pereira_passos",hidroplants,incremental_natural_flows,step)
    
        #balances every plant's reservoir for next timestep and updates its registries
        push!(depletion_stages,stage)
        push!(equivalent_reservoir, paraibuna_do_sul_equivalent_reservoir_status(hidroplants))
        updates_registries(hidroplants, incremental_natural_flows, step)

        if verbose
            if step != 1
                print("\u1b[1F")
            end
            print("Simulation progress: $(100*step/timesteps)%")
            print("\u1b[0K")
            println()
        end
    end

    if !isdir(joinpath(case_name,"results"))
        mkdir(joinpath(case_name,"results"))
    end

    df_reservoir = DataFrame(
        step = 1:timesteps,
        month = months,
        stage = depletion_stages,
        ps_equivalent_reservoir = equivalent_reservoir
    )
    df_irrigation = DataFrame(
        step = 1:timesteps,
        month = months,
        stage = depletion_stages,
        ps_equivalent_reservoir = equivalent_reservoir
    )
    df_turbining = DataFrame(
        step = 1:timesteps,
        month = months,
        stage = depletion_stages,
        ps_equivalent_reservoir = equivalent_reservoir
    )
    df_spillage = DataFrame(
        step = 1:timesteps,
        month = months,
        stage = depletion_stages,
        ps_equivalent_reservoir = equivalent_reservoir
    )
    df_incremental_flows = DataFrame(
        step = 1:timesteps,
        month = months,
        stage = depletion_stages,
        ps_equivalent_reservoir = equivalent_reservoir
    )
    df_generation = DataFrame(
        step = 1:timesteps,
        month = months,
        stage = depletion_stages,
        ps_equivalent_reservoir = equivalent_reservoir
    )
    df_evaporation = DataFrame(
        step = 1:timesteps,
        month = months,
        stage = depletion_stages,
        ps_equivalent_reservoir = equivalent_reservoir
    )

    for (name, plant) in hidroplants

        df_reservoir[!,name] = plant.reservoir_timeline
        df_irrigation[!,name] = repeat(plant.irrigation, outer = years+1)[1:timesteps]
        df_turbining[!,name] = plant.turbine_timeline
        df_spillage[!,name] = plant.spill_timeline
        df_incremental_flows[!,name] = incremental_natural_flows[name]
        df_generation[!,name] = plant.generation_timeline
        df_evaporation[!,name] = plant.evaporation_timeline

    end

    if findlast("\\",case_name) !== nothing || findlast("/",case_name) !== nothing
        if findlast("\\",case_name) !== nothing && findlast("/",case_name) !== nothing
            bar_pos = findlast("\\",case_name) > findlast("/",case_name) ? findlast("\\",case_name) : findlast("/",case_name)
        else
            bar_pos = findlast("\\",case_name) !== nothing ? findlast("\\",case_name) : findlast("/",case_name)
        end
        name = case_name[bar_pos[end]+1:end]
    else
        name = case_name
    end
    CSV.write(joinpath(case_name,"results",name*"_reservoir_hm3.csv"),df_reservoir)
    CSV.write(joinpath(case_name,"results",name*"_turbining_m3_per_sec.csv"),df_turbining)
    CSV.write(joinpath(case_name,"results",name*"_spillage_m3_per_sec.csv"),df_spillage)
    CSV.write(joinpath(case_name,"results",name*"_incremental_flow_m3_per_sec.csv"),df_incremental_flows)
    CSV.write(joinpath(case_name,"results",name*"_generation_MW.csv"),df_generation)
    CSV.write(joinpath(case_name,"results",name*"_evaporation_m3_per_sec.csv"),df_evaporation)

    out = "Simulation complete, results available at: $(case_name)/results"
    println(out)
    return out
end

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
    poly_generation::Union{String,Array{Float64, 1}}
    wait_vol::Union{String,Array{Float64, 1}}
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
    generation_timeline = []            #MW

end

function _generation_regression(input_folder::String,name::Union{String,String15})
    file_path = joinpath(input_folder,"generation_data",name*".csv")
    try
        df_generation = DataFrame(CSV.File(file_path))[:,["QTUR","VOLF","GHID"]]
        fm = @formula(GHID ~ QTUR + VOLF)
        sm = lm(fm, df_generation)
        return coef(sm)
    catch
        df_generation = DataFrame(CSV.File(file_path))[:,["QTURB","VOLF","GHIDR"]]
        fm = @formula(GHIDR ~ QTURB + VOLF)
        sm = lm(fm, df_generation)
        return coef(sm)
    end
    
end

function read_flow(path::String)
    array = []
    file = CSV.File(path,header=false)
    for row in file
        for column in row
            if !ismissing(column)
                push!(array,Float64(column))
            end
        end
    end
    return array
end

"""
Reads flow time series and generates statistical data about flows for later stochastic generation of random values.
"""
function flow_compiler(input_folder::String,hidroplants::Dict)
    folder_path = joinpath(input_folder,"flow_data")
    files = readdir(folder_path)
    df_topology = DataFrame(CSV.File(joinpath(input_folder,"topology.csv")))
    df_flows = Dict()
    length = 0
    for file in files
        name = file[1:end-4]
        data = read_flow(joinpath(folder_path,file))
        for i in 1:size(df_topology, 1)
            if df_topology[i,"downstream"] == name
                plant = df_topology[i,"plant"]
                upstream = read_flow(joinpath(folder_path,plant*".csv"))
                data -= upstream
            end
        end
        
        df_flows[name] = data
        length = size(data)
    end

    for name in keys(hidroplants)
        if !(name in keys(df_flows))
            df_flows[name] = zeros(length)
        end
    end

    return df_flows
end

"""
Loads hidroplants parameters from files to structs. Returns dictionary of `hidroplant`.
"""
function loads_hidroplants(input_folder::String)
    file_path = joinpath(input_folder,"hidroplants_params.csv")
    df = DataFrame(CSV.File(file_path))
    hidroplants = Dict()
    for i in 1:size(df,1)
        name = df[i,"name"]
        if name in [name[1:end-4] for name in readdir(joinpath(input_folder,"irrigation_data"))]
            irrigation = vec(readdlm(joinpath(input_folder,"irrigation_data",name*".csv"), '\t', Float64))
        else
            irrigation = zeros(12)
        end

        if name in [name[1:end-4] for name in readdir(joinpath(input_folder,"wait_data"))]
            wait_vol = vec(readdlm(joinpath(input_folder,"wait_data",name*".csv"), '\t', Float64))
        else
            wait_vol = "nothing"
        end
        
        if name in [name[1:end-4] for name in readdir(joinpath(input_folder,"generation_data"))]
            poly_generation = _generation_regression(input_folder,name)
        elseif (name == "fontes_bc" || name == "fontes_a") && "fontes" in [name[1:end-4] for name in readdir(joinpath(input_folder,"generation_data"))]
            poly_generation = _generation_regression(input_folder,"fontes")
        else
            poly_generation = "nothing"
        end
        
        if name in [name[1:end-4] for name in readdir(joinpath(input_folder,"evaporation_data","coefficients"))]
            evaporation_coef = vec(readdlm(joinpath(input_folder,"evaporation_data","coefficients",name*".csv"), '\t', Float64))
            if name in [name[1:end-4] for name in readdir(joinpath(input_folder,"evaporation_data","polynomials"))]
                polynomials = readdlm(joinpath(input_folder,"evaporation_data","polynomials",name*".csv"), '\t', Float64)
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

        volume = df[i,"min_reservoir"] + df[i,"volume_start"]*(df[i,"max_reservoir"] - df[i,"min_reservoir"])

        hidroplants[name] = hidroplant(
            name = name,
            max_spillage = df[i,"max_spillage"],
            min_spillage = df[i,"min_spillage"],
            max_turbining = df[i,"max_turbining"]*(1 - df[i,"IH"]),
            min_turbining = df[i,"min_turbining"],
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
            poly_generation = poly_generation,
            wait_vol = wait_vol,
            area = df[i,"area"]
        )
    end
    return hidroplants
end

"""
Will balance every plant's reservoir for next timestep and update its registries.
"""
function updates_registries(hidroplants::Dict, incremental_natural_flows::Dict,step::Int64)
    fontes_reservoir = hidroplants["fontes_a"].reservoir + hidroplants["fontes_bc"].reservoir
    month = mod(step, 12) == 0 ? 12 : mod(step, 12)
    for (name, plant) in hidroplants
        push!(plant.spill_timeline, plant.spilling)
        push!(plant.turbine_timeline, plant.turbining)
        push!(plant.reservoir_timeline, plant.reservoir)
        push!(plant.inflow_timeline, plant.inflow)
        push!(plant.evaporation_timeline, hm3_per_month_to_m3_per_sec(plant.evaporation,month))
        if plant.poly_generation != "nothing"
            if name == "fontes_a" || name == "fontes_bc"
                poly = plant.poly_generation
                generation = poly[1] + poly[2]*plant.turbining + poly[3]*fontes_reservoir
                generation = generation >= 0 ? generation : 0.0
                push!(plant.generation_timeline, generation)
            else
                poly = plant.poly_generation
                generation = poly[1] + poly[2]*plant.turbining + poly[3]*plant.reservoir
                generation = generation >= 0 ? generation : 0.0
                push!(plant.generation_timeline, generation)
            end
        else
            push!(plant.generation_timeline, plant.turbining*plant.generation_coef)
        end
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
        pvq = Polynomial(hidroplants[name].poly_volume_quote)
        pqa = Polynomial(hidroplants[name].poly_quote_area)
        q = pvq(hidroplants[name].reservoir)
        hidroplants[name].area = pqa(q)
    end
    hidroplants[name].evaporation =  hidroplants[name].area * hidroplants[name].evaporation_coef[month]/1000
    incremental_flow -= hidroplants[name].evaporation
    incremental_flow -= m3_per_sec_to_hm3_per_month(hidroplants[name].irrigation[month], month)
    hidroplants[name].inflow = incremental_flow
end

"""
Calculates % of equivalent reservoir.
"""
function paraibuna_do_sul_equivalent_reservoir_status(hidroplants::Dict)
    equiv_max = 0
    equiv_min = 2953
    equiv_current = 0
    for name in ["funil","sta_branca","jaguari","paraibuna"]
        equiv_max += hidroplants[name].max_reservoir
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

    if final_reservoir > hidroplants[name].max_reservoir
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
            ask_previous_plants(name, hidroplants, hidroplants[name].min_reservoir_ope - final_reservoir,month)
            updates_inflow(name, hidroplants, incremental_natural_flows, step)
            final_reservoir = hidroplants[name].reservoir + hidroplants[name].inflow - m3_per_sec_to_hm3_per_month(hidroplants[name].min_turbining, month) - m3_per_sec_to_hm3_per_month(hidroplants[name].min_spillage, month)
        end
        if final_reservoir*(1-0.00001) <= hidroplants[name].min_reservoir_ope
            if final_reservoir*(1-0.00001) <= hidroplants[name].min_reservoir
                if hidroplants[name].reservoir + hidroplants[name].inflow - hidroplants[name].min_reservoir >= 0
                    hidroplants[name].turbining = hm3_per_month_to_m3_per_sec(hidroplants[name].reservoir + hidroplants[name].inflow - hidroplants[name].min_reservoir,month)
                    hidroplants[name].spilling = 0
                else
                    hidroplants[name].turbining = 0
                    hidroplants[name].spilling = 0
                end
            else
                hidroplants[name].turbining = hidroplants[name].min_turbining
                hidroplants[name].spilling = hidroplants[name].min_spillage
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
function ask_previous_plants(name::Union{String15,String},hidroplants::Dict,value::Float64,month::Int64;last_resource_available = true, stage::Int64 = 1, filling_mode = 1,complete_depletion = false)
    extra_acquired = 0.0
    start_value = value
    if name == "funil"
        previous_ones = ["sta_branca","jaguari"]
    else
        previous_ones = _gets_turbine_from(name,hidroplants)
    end
    if previous_ones == [] || value == 0
        return 0.0
    end
    lacking = 0.0
    for previous in previous_ones
        value -= extra_acquired
        min = complete_depletion ? hidroplants[previous].min_reservoir : hidroplants[previous].min_reservoir_ope
        if complete_depletion && previous == "jaguari"
        end
        if hidroplants[previous].reservoir - value > min
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
            available = hidroplants[previous].reservoir - min > 0 ? hidroplants[previous].reservoir - min : 0.0
            lacking = value - available
            extra_from_previous = ask_previous_plants(previous,hidroplants,lacking,month,complete_depletion = complete_depletion)
            available += extra_from_previous
            if hidroplants[previous].turbining + hm3_per_month_to_m3_per_sec(available,month) < hidroplants[previous].max_turbining
                hidroplants[previous].turbining += hm3_per_month_to_m3_per_sec(available,month)
            else
                can_turbinate = hidroplants[previous].max_turbining - hidroplants[previous].turbining
                hidroplants[previous].turbining += can_turbinate
                hidroplants[previous].spilling += hm3_per_month_to_m3_per_sec(available,month) - can_turbinate
            end
            hidroplants[previous].reservoir -= available - extra_from_previous
            extra_acquired += available
            if extra_acquired >= start_value
                return extra_acquired
            end
        end
    end
    if last_resource_available && name == "sta_clara"
        hidroplants["paraibuna"].min_reservoir_ope = hidroplants["paraibuna"].min_reservoir - 425
        extra_acquired += ask_previous_plants(name,hidroplants,start_value - extra_acquired,month::Int64;last_resource_available = false)
    end
    if name == "sta_cecilia" && hidroplants["paraibuna"].reservoir > hidroplants["paraibuna"].min_reservoir - 425
        paraibuna_do_sul_depletion_update(hidroplants,month,stage,filling_mode)
        extra_acquired += ask_previous_plants("sta_cecilia",hidroplants,start_value - extra_acquired,month)
        if extra_acquired >= start_value
            return extra_acquired
        end
    end
    if name == "sta_cecilia" && (reservoir_status("funil",hidroplants) > 0 || reservoir_status("sta_branca",hidroplants) > 0 || reservoir_status("jaguari",hidroplants) > 0) && hidroplants["paraibuna"].reservoir == hidroplants["paraibuna"].min_reservoir - 425
        last_resource = ask_previous_plants("sta_cecilia",hidroplants,start_value - extra_acquired,month,complete_depletion = true)
    end
    return extra_acquired
end

"""
Operates Santa Cecilia plant.
"""
function operates_sta_cecilia_plant(hidroplants::Dict,incremental_natural_flows::Dict,step::Int64,stage::Int64,filling_mode::Int64,eighty_policiy::Bool)
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

    if paraibuna_do_sul_equivalent_reservoir_status(hidroplants) >= 0.8 && eighty_policiy
        excess = hm3_per_month_to_m3_per_sec(reservoir,month) + hm3_per_month_to_m3_per_sec(inflow,month) - max_spillage - max_turbining - hm3_per_month_to_m3_per_sec(max_reservoir,month)
        excess = excess > 0 ? 0.0 : excess
        ask_previous_plants("sta_cecilia",hidroplants,m3_per_sec_to_hm3_per_month((-1)*excess,month),month;stage = stage)
    end
    
    updates_inflow("sta_cecilia", hidroplants, incremental_natural_flows, step)
    inflow =  hidroplants["sta_cecilia"].inflow
    excess = hm3_per_month_to_m3_per_sec(reservoir,month) + hm3_per_month_to_m3_per_sec(inflow,month) - min_spillage - min_turbining - hm3_per_month_to_m3_per_sec(max_reservoir,month)
    
    if excess < 0
        ask_previous_plants("sta_cecilia",hidroplants,m3_per_sec_to_hm3_per_month((-1)*excess,month),month;stage = stage,filling_mode = filling_mode)
        updates_inflow("sta_cecilia", hidroplants, incremental_natural_flows, step)
        inflow =  hidroplants["sta_cecilia"].inflow
    end
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
function paraibuna_do_sul_depletion_update(hidroplants::Dict,month::Int64,previous_stage::Int64,filling_mode::Int64)
    for (_,plant) in hidroplants
        if plant.wait_vol != "nothing"
            plant.max_reservoir = plant.wait_vol[month]
        end
    end
    if filling_mode == 2
        if previous_stage == 2 && (0.7*(1+0.05) >= reservoir_status("sta_branca",hidroplants) || 0.8*(1+0.05) >= reservoir_status("paraibuna",hidroplants) || 0.8*(1+0.05) >= reservoir_status("jaguari",hidroplants))
            skip_to = 2
        elseif previous_stage == 3 && (0.4*(1+0.05) >= reservoir_status("sta_branca",hidroplants) || 0.4*(1+0.05) >= reservoir_status("paraibuna",hidroplants) || 0.5*(1+0.05) >= reservoir_status("jaguari",hidroplants))
            skip_to = 3
        end
    end
    skip_to = 1
    stage = 1
    hidroplants["funil"].min_reservoir_ope = 0.3*(hidroplants["funil"].max_reservoir - hidroplants["funil"].min_reservoir) + hidroplants["funil"].min_reservoir
    hidroplants["sta_branca"].min_reservoir_ope = 0.7*(hidroplants["sta_branca"].max_reservoir - hidroplants["sta_branca"].min_reservoir) + hidroplants["sta_branca"].min_reservoir
    hidroplants["paraibuna"].min_reservoir_ope = 0.8*(hidroplants["paraibuna"].max_reservoir - hidroplants["paraibuna"].min_reservoir) + hidroplants["paraibuna"].min_reservoir
    hidroplants["jaguari"].min_reservoir_ope = 0.8*(hidroplants["jaguari"].max_reservoir - hidroplants["jaguari"].min_reservoir) + hidroplants["jaguari"].min_reservoir
    if 0.3*(1+0.05) >= reservoir_status("funil",hidroplants) && 0.7*(1+0.05) >= reservoir_status("sta_branca",hidroplants) && 0.8*(1+0.05) >= reservoir_status("paraibuna",hidroplants) && 0.8*(1+0.05) >= reservoir_status("jaguari",hidroplants) || skip_to >= 2
        stage = 2
        hidroplants["sta_branca"].min_reservoir_ope = 0.4*(hidroplants["sta_branca"].max_reservoir - hidroplants["sta_branca"].min_reservoir) + hidroplants["sta_branca"].min_reservoir
        if 0.4*(1+0.05) >= reservoir_status("sta_branca",hidroplants) || skip_to >= 2
            hidroplants["paraibuna"].min_reservoir_ope = 0.4*(hidroplants["paraibuna"].max_reservoir - hidroplants["paraibuna"].min_reservoir) + hidroplants["paraibuna"].min_reservoir
            if 0.4*(1+0.05) >= reservoir_status("paraibuna",hidroplants) || skip_to >= 2
                hidroplants["jaguari"].min_reservoir_ope = 0.5*(hidroplants["jaguari"].max_reservoir - hidroplants["jaguari"].min_reservoir) + hidroplants["jaguari"].min_reservoir
                if 0.5*(1+0.05) >= reservoir_status("jaguari",hidroplants) || skip_to >= 3
                    stage = 3
                    hidroplants["sta_branca"].min_reservoir_ope = 0.1*(hidroplants["sta_branca"].max_reservoir - hidroplants["sta_branca"].min_reservoir) + hidroplants["sta_branca"].min_reservoir
                    if 0.1*(1+0.05) >= reservoir_status("sta_branca",hidroplants) || skip_to >= 3
                        hidroplants["paraibuna"].min_reservoir_ope = 0.05*(hidroplants["paraibuna"].max_reservoir - hidroplants["paraibuna"].min_reservoir) + hidroplants["paraibuna"].min_reservoir
                        if 0.05*(1+0.05) >= reservoir_status("paraibuna",hidroplants) || skip_to >= 3
                            hidroplants["jaguari"].min_reservoir_ope = 0.2*(hidroplants["jaguari"].max_reservoir - hidroplants["jaguari"].min_reservoir) + hidroplants["jaguari"].min_reservoir
                            if 0.2*(1+0.05) >= reservoir_status("jaguari",hidroplants) || skip_to >= 3
                                stage = 4
                                #hidroplants["paraibuna"].min_reservoir_ope = 0.2*(hidroplants["paraibuna"].max_reservoir - hidroplants["paraibuna"].min_reservoir) + hidroplants["paraibuna"].min_reservoir - 425
                                hidroplants["paraibuna"].min_reservoir_ope = hidroplants["paraibuna"].min_reservoir - 425
                            end
                        end
                    end
                end
            end
        end
    end
    return stage
end

"File with utility methods for simulating Paraiba do Sul"


