#including utilities
include("utilities.jl")

######################## PARAMETERS #########################

#number of timesteps for simulation, in months
timesteps = 12*5

#if to display simulation progress
verbose = true

#initial status of reservoir_start
reservoir_start = "min"

#to manipulate natural incremental flows
bias = 0.0

#degree of turbine sensitivity regarding the plant's reservoir
n = 4

######################### EXECUTION #########################

if verbose println("########### SIMULATION START ###########") end

#loads parameters for stochastic generation of incremental flows
sfp = stochastic_flow_compiler("flow_data")

#loads hidroplants from parameters file
hidroplants = loads_hidroplants("hidroplants_params.csv", reservoir_start = reservoir_start)
if verbose println("# Plants have been successfully loaded.") end

#generates incremental flows for simulation
incremental_natural_flows = loads_stochastic_incremental_flows(sfp, hidroplants,timesteps, bias)
if verbose println("# Stochastic incremental natural flows have been successfully generated.") end

for step in 1:timesteps
    month = mod(step, 12) == 0 ? 12 : mod(step, 12)

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
    if verbose println("# System of Paraibuna do Sul is in $(stage) depletion stage.") end

    #Jaguari operation
    operate_reservoir_plant("jaguari",hidroplants,incremental_natural_flows,step)

    #Paraibuna operation
    operate_reservoir_plant("paraibuna",hidroplants,incremental_natural_flows,step)

    #Sta Branca operation
    operate_reservoir_plant("sta_branca",hidroplants,incremental_natural_flows,step)

    #Funil operation
    operate_reservoir_plant("funil",hidroplants,incremental_natural_flows,step)
    @show hm3_per_month_to_m3_per_sec(incremental_natural_flows["funil"][step],month)
    @show hidroplants["sta_branca"].turbining
    @show hidroplants["sta_branca"].spilling
    @show hidroplants["paraibuna"].turbining
    @show hidroplants["paraibuna"].spilling
    @show hidroplants["funil"].reservoir
    @show hidroplants["funil"].turbining
    @show hidroplants["funil"].spilling
    @show hm3_per_month_to_m3_per_sec(hidroplants["funil"].inflow, month)

    #Santa Cecilia operation
    operates_sta_cecilia_plant(hidroplants,incremental_natural_flows,step)
    @show hm3_per_month_to_m3_per_sec(incremental_natural_flows["sta_cecilia"][step],month)
    @show hidroplants["funil"].turbining
    @show hidroplants["funil"].spilling
    @show hidroplants["sta_cecilia"].reservoir
    @show hidroplants["sta_cecilia"].turbining
    @show hidroplants["sta_cecilia"].spilling
    @show hm3_per_month_to_m3_per_sec(hidroplants["sta_cecilia"].inflow, month)

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