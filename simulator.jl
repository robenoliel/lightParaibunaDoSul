#including utilities
include("utilities.jl")

######################## PARAMETERS #########################

#number of timesteps for simulation, in months
timesteps = 12*5

#if to display simulation progress
verbose = true

#initial status of reservoir_start
reservoir_start = "max"

#to manipulate natural incremental flows
bias = -50.0

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

    #Updates deprecation status
    paraibuna_do_sul_depletion_update(hidroplants)

    #Jaguari operation
    operate_reservoir_plant("jaguari",hidroplants,incremental_natural_flows,step)
    """
    @show reservoir_status("jaguari",hidroplants)
    @show hidroplants["jaguari"].turbining
    @show hm3_per_month_to_m3_per_sec(hidroplants["jaguari"].inflow, month)
    """

    #Paraibuna operation
    operate_reservoir_plant("paraibuna",hidroplants,incremental_natural_flows,step)
    """
    @show reservoir_status("paraibuna",hidroplants)
    @show hidroplants["paraibuna"].turbining
    @show hm3_per_month_to_m3_per_sec(hidroplants["paraibuna"].inflow, month)
    """

    #Sta Branca operation
    operate_reservoir_plant("sta_branca",hidroplants,incremental_natural_flows,step)
    """
    @show reservoir_status("sta_branca",hidroplants)
    @show hidroplants["sta_branca"].reservoir
    @show hidroplants["sta_branca"].min_reservoir_ope
    @show hidroplants["sta_branca"].turbining
    @show hm3_per_month_to_m3_per_sec(hidroplants["sta_branca"].inflow, month)
    """

    #Funil operation
    operate_reservoir_plant("funil",hidroplants,incremental_natural_flows,step)
    """
    @show reservoir_status("funil",hidroplants)
    @show hidroplants["funil"].turbining
    @show hm3_per_month_to_m3_per_sec(hidroplants["funil"].inflow, month)
    """

    @show reservoir_status("funil",hidroplants)
    @show reservoir_status("sta_branca",hidroplants)
    @show reservoir_status("paraibuna",hidroplants)
    @show reservoir_status("jaguari",hidroplants)

    #balances every plant's reservoir for next timestep and updates its registries  
    hidro_balances_and_updates_registries(hidroplants, incremental_natural_flows, step)
    if verbose println("# Time step $(step) of simulation has been successfully completed.") end
end