include("utilities.jl")

sfp = stochastic_flow_compiler("flow_data")
@show stochastic_flow_generator(sfp,"nilo_pecanha",1)