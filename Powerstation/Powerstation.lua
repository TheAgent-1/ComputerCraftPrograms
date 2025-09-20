-- Powerstation Monitor and Control System
-- NOW ON GITEA

-- API endpoint
local API = "http://192.168.1.41:5005/powerstation"

-- Locate the peripherals
local Accumulator0 = peripheral.find("modular_accumulator_3") -- Add "_<number>" if multiple accumulators
local Accumulator1 = peripheral.find("modular_accumulator_4") -- Add "_<number>" if multiple accumulators

-- check if accumulators are found
if not Accumulator0 and not Accumulator1 then
    error("No modular accumulators found. Please connect at least one modular accumulator.")
end