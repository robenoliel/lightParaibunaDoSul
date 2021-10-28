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
incremental_flows = loads_stochastic_incremental_flows(sfp, hidroplants,timesteps)
if verbose println("# Stochastic incremental flows have been successfully generated.") end