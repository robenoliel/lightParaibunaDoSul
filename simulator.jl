#including utilities
include("utilities.jl")

######################## PARAMETERS #########################

#number of timesteps for simulation, in months
timesteps = 12

#if to display simulation progress
verbose = true

#degree of turbine sensitivity regarding the plant's reservoir
n = 4

######################### EXECUTION #########################

if verbose println("########### SIMULATION START ###########") end

#loads parameters for stochastic generation of incremental flows
sfp = stochastic_flow_compiler("flow_data")

#loads hidroplants from parameters file
hidroplants = loads_hidroplants("hidroplants_params.csv", reservoir_start = "mean")
if verbose println("# Plants have been successfully loaded.") end

#generates incremental flows for simulation
incremental_natural_flows = loads_stochastic_incremental_flows(sfp, hidroplants,timesteps)
if verbose println("# Stochastic incremental natural flows have been successfully generated.") end

for step in 1:timesteps
    month = mod(step, 12) == 0 ? 12 : mod(step, 12)

    #Tocos operation: to keep reservoir at same volume, will turbine all it's incremental flow, and spill what's beyond its turbination limit.
    updates_inflow("tocos", hidroplants, incremental_natural_flows, step)
    if hidroplants["tocos"].inflow <= m3_per_sec_to_hm3_per_month(hidroplants["tocos"].max_turbining, month)
        hidroplants["tocos"].turbining = hm3_per_month_to_m3_per_sec(hidroplants["tocos"].inflow, month)
        hidroplants["tocos"].spilling = 0.0
    else
        excess = hm3_per_month_to_m3_per_sec(hidroplants["tocos"].inflow, month) - hidroplants["tocos"].max_turbining
        hidroplants["tocos"].turbining = hidroplants["tocos"].max_turbining
        hidroplants["tocos"].spilling = excess
    end

    #Lajes operation
    updates_inflow("lajes", hidroplants, incremental_natural_flows, step)
    hidroplants["lajes"].turbining = calculates_turbine("lajes",hidroplants,n)
    volume = hidroplants["lajes"].reservoir + hidroplants["lajes"].inflow
    volume -= m3_per_sec_to_hm3_per_month(hidroplants["lajes"].irrigation[month], month) + m3_per_sec_to_hm3_per_month(hidroplants["lajes"].turbining, month)
    if  volume > hidroplants["lajes"].max_reservoir
        hidroplants["lajes"].spilling = hm3_per_month_to_m3_per_sec(volume, month)
    end

    #Fontes_a operation: to keep reservoir at same volume, will turbine all it's incremental flow, and spill what's beyond its turbination limit.
    updates_inflow("fontes_a", hidroplants, incremental_natural_flows, step)
    if hidroplants["fontes_a"].inflow <= m3_per_sec_to_hm3_per_month(hidroplants["fontes_a"].max_turbining, month)
        hidroplants["fontes_a"].turbining = hm3_per_month_to_m3_per_sec(hidroplants["fontes_a"].inflow, month)
        hidroplants["fontes_a"].spilling = 0.0
    else
        excess = hm3_per_month_to_m3_per_sec(hidroplants["fontes_a"].inflow, month) - hidroplants["fontes_a"].max_turbining
        hidroplants["fontes_a"].turbining = hidroplants["fontes_a"].max_turbining
        hidroplants["fontes_a"].spilling = excess
    end
    
    #Picada operation
    updates_inflow("picada", hidroplants, incremental_natural_flows, step)
    if hidroplants["picada"].inflow <= m3_per_sec_to_hm3_per_month(hidroplants["picada"].max_turbining, month)
        hidroplants["picada"].turbining = hm3_per_month_to_m3_per_sec(hidroplants["picada"].inflow, month)
        hidroplants["picada"].spilling = 0.0
    else
        excess = hm3_per_month_to_m3_per_sec(hidroplants["picada"].inflow, month) - hidroplants["picada"].max_turbining
        hidroplants["picada"].turbining = hidroplants["picada"].max_turbining
        hidroplants["picada"].spilling = excess
    end

    #Sobragi operation
    updates_inflow("sobragi", hidroplants, incremental_natural_flows, step)
    if hidroplants["sobragi"].inflow <= m3_per_sec_to_hm3_per_month(hidroplants["sobragi"].max_turbining, month)
        hidroplants["sobragi"].turbining = hm3_per_month_to_m3_per_sec(hidroplants["sobragi"].inflow, month)
        hidroplants["sobragi"].spilling = 0.0
    else
        excess = hm3_per_month_to_m3_per_sec(hidroplants["sobragi"].inflow, month) - hidroplants["sobragi"].max_turbining
        hidroplants["sobragi"].turbining = hidroplants["sobragi"].max_turbining
        hidroplants["sobragi"].spilling = excess
    end
    @show hidroplants["sobragi"].reservoir
    @show hidroplants["sobragi"].turbining
    
    #balances every plant's reservoir for next timestep and updates its registries
    hidro_balances_and_updates_registries(hidroplants, incremental_natural_flows, step)
    if verbose println("# Time step $(step) of simulation has been successfully completed.") end
end