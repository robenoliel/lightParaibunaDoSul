#including utilities
include("utilities.jl")

######################## PARAMETERS #########################

#Study case name
case_name = "study_case_regression"

#initial volumes
init_vol = Dict(
    "funil" => 0.5,
    "sta_branca" => 0.75,
    "paraibuna" => 0.85,
    "jaguari" => 0.85
)

# 1 or 2 only
filling_mode = 1

#put something here
eighty_policiy = true

#if to display simulation progress
verbose = false

#initial status of reservoir_start
reservoir_start = "mean"

"""
#to manipulate natural incremental flows
bias = 0.0

#degree of turbine sensitivity regarding the plant's reservoir
n = 4
"""

######################### EXECUTION #########################

if verbose println("########### SIMULATION START ###########") end


#loads incremental flows for simulation
incremental_natural_flows = flow_compiler("flow_data")
timesteps = size(incremental_natural_flows["funil"],1)
years = Int64(trunc(timesteps/12))
if verbose println("# Stochastic incremental natural flows have been successfully generated.") end

hidroplants = loads_hidroplants("hidroplants_params.csv",reservoir_start = reservoir_start,paraibuna_start = init_vol)

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
    if verbose println("# System of Paraibuna do Sul is in $(stage) depletion stage.") end  
    updates_registries(hidroplants, incremental_natural_flows, step)
    if verbose println("# Time step $(step) of simulation has been successfully completed.") end
end

if !isdir(joinpath("results",case_name))
    mkdir(joinpath("results",case_name))
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

CSV.write(joinpath("results",case_name,case_name*"_reservoir_hm3.csv"),df_reservoir)
CSV.write(joinpath("results",case_name,case_name*"_irrigation_m3_per_sec.csv"),df_irrigation)
CSV.write(joinpath("results",case_name,case_name*"_turbining_m3_per_sec.csv"),df_turbining)
CSV.write(joinpath("results",case_name,case_name*"_spillage_m3_per_sec.csv"),df_spillage)
CSV.write(joinpath("results",case_name,case_name*"_incremental_flow_m3_per_sec.csv"),df_incremental_flows)
CSV.write(joinpath("results",case_name,case_name*"_generation_MW.csv"),df_generation)
CSV.write(joinpath("results",case_name,case_name*"_evaporation_m3_per_sec.csv"),df_evaporation)