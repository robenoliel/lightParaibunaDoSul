#including utilities
include("utilities.jl")

######################## PARAMETERS #########################

#Study case name
case_name = "case_1"

#number of years for simulation
years = 90

#if to display simulation progress
verbose = true

#initial status of reservoir_start
reservoir_start = "mean"

#to manipulate natural incremental flows
bias = 0.0

"""
#degree of turbine sensitivity regarding the plant's reservoir
n = 4
"""

######################### EXECUTION #########################

if verbose println("########### SIMULATION START ###########") end

timesteps = 12*years

#loads incremental flows for simulation
incremental_natural_flows = flow_compiler("flow_data",years)
if verbose println("# Stochastic incremental natural flows have been successfully generated.") end

hidroplants = loads_hidroplants("hidroplants_params.csv",reservoir_start= "mean")

depletion_stages = []
equivalent_reservoir = []

for step in 1:timesteps
    month = mod(step, 12) == 0 ? 12 : mod(step, 12)
    push!(equivalent_reservoir, paraibuna_do_sul_equivalent_reservoir_status(hidroplants))

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
    stage = paraibuna_do_sul_depletion_update(hidroplants)
    push!(depletion_stages,stage)
    if verbose println("# System of Paraibuna do Sul is in $(stage) depletion stage.") end

    #Jaguari operation
    operate_reservoir_plant("jaguari",hidroplants,incremental_natural_flows,step)

    #Paraibuna operation
    operate_reservoir_plant("paraibuna",hidroplants,incremental_natural_flows,step)

    #Sta Branca operation
    operate_reservoir_plant("sta_branca",hidroplants,incremental_natural_flows,step)

    #Funil operation
    operate_reservoir_plant("funil",hidroplants,incremental_natural_flows,step)

    #Santa Cecilia operation
    operates_sta_cecilia_plant(hidroplants,incremental_natural_flows,step)

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
    hidro_balances_and_updates_registries(hidroplants, incremental_natural_flows, step)
    if verbose println("# Time step $(step) of simulation has been successfully completed.") end
end

if !isdir(joinpath("results",case_name))
    mkdir(joinpath("results",case_name))
end

df_reservoir = DataFrame(
    step = 1:timesteps,
    month = repeat(1:12, outer = years),
    stage = depletion_stages,
    ps_equivalent_reservoir = equivalent_reservoir
)
df_irrigation = DataFrame(
    step = 1:timesteps,
    month = repeat(1:12, outer = years),
    stage = depletion_stages,
    ps_equivalent_reservoir = equivalent_reservoir
)
df_turbining = DataFrame(
    step = 1:timesteps,
    month = repeat(1:12, outer = years),
    stage = depletion_stages,
    ps_equivalent_reservoir = equivalent_reservoir
)
df_spillage = DataFrame(
    step = 1:timesteps,
    month = repeat(1:12, outer = years),
    stage = depletion_stages,
    ps_equivalent_reservoir = equivalent_reservoir
)
df_incremental_flows = DataFrame(
    step = 1:timesteps,
    month = repeat(1:12, outer = years),
    stage = depletion_stages,
    ps_equivalent_reservoir = equivalent_reservoir
)
df_generation = DataFrame(
    step = 1:timesteps,
    month = repeat(1:12, outer = years),
    stage = depletion_stages,
    ps_equivalent_reservoir = equivalent_reservoir
)

for (name, plant) in hidroplants

    df_reservoir[!,name] = plant.reservoir_timeline
    df_irrigation[!,name] = repeat(plant.irrigation, outer = years)
    df_turbining[!,name] = plant.turbine_timeline
    df_spillage[!,name] = plant.spill_timeline
    df_incremental_flows[!,name] = incremental_natural_flows[name]
    df_generation[!,name] = plant.turbine_timeline * plant.generation_coef

end

CSV.write(joinpath("results",case_name,"reservoir.csv"),df_reservoir)
CSV.write(joinpath("results",case_name,"irrigation.csv"),df_irrigation)
CSV.write(joinpath("results",case_name,"turbining.csv"),df_turbining)
CSV.write(joinpath("results",case_name,"spillage.csv"),df_spillage)
CSV.write(joinpath("results",case_name,"incremental_flow.csv"),df_incremental_flows)
CSV.write(joinpath("results",case_name,"generation.csv"),df_generation)


