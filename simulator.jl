include("utilities.jl")

sfp = stochastic_flow_compiler("flow_data")
stochastic_flow_generator(sfp,"nilo_pecanha",1)

loads_hidroplants("hidroplants_params.csv")