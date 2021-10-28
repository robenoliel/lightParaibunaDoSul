#including utilities
include("utilities.jl")

######################## PARAMETERS #########################

#number of timesteps for simulation, in months
timesteps = 12

#if to display simulation progress
verbose = true

######################### EXECUTION #########################

if verbose println("########### SIMULATION START ###########") end

#loads parameters for stochastic generation of incremental flows
sfp = stochastic_flow_compiler("flow_data")

#loads hidroplants from parameters file
hidroplants = loads_hidroplants("hidroplants_params.csv")
if verbose println("# Plants have been successfully loaded.") end

#generates incremental flows for simulation
incremental_natural_flows = loads_stochastic_incremental_flows(sfp, hidroplants,timesteps)
if verbose println("# Stochastic incremental natural flows have been successfully generated.") end

for step in 1:timesteps

    #balances every plant's reservoir for next timestep and updates its registries
    hidro_balances_and_updates(hidroplants, incremental_natural_flows, step)
    if verbose println("# Time step $(step) of simulation has been successfully completed.") end
end