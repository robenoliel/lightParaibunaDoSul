using Test

include("../src/simulatorParaibaDoSul.jl")
const SPS = simulatorParaibaDoSul

case_name = "example"
input_folder = "../$(case_name)"

@testset "simulatorParaibaDoSul" begin

    @testset "Locates example files" begin
        @test isdir(input_folder)
        for folder in ["evaporation_data","flow_data","generation_data","irrigation_data"]
            @test isdir(joinpath(input_folder,folder))
        end
        for file in ["hidroplants_params.csv","topology.csv"]
            @test isfile(joinpath(input_folder,file))
        end
    end

    @testset "Runs simulation" begin
        @test SPS.run_simulation(input_folder) == "Simulation complete, results available at: $(input_folder)/results"
    end
end