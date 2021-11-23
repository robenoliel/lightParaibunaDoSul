include("./src/simulatorParaibaDoSul.jl")

const SPS = simulatorParaibaDoSul
if length(ARGS) == 1
    SPS.run_simulation(ARGS[1])
elseif length(ARGS) == 2
    SPS.run_simulation(ARGS[1],ARGS[2])
end