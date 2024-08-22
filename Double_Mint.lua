--[[
-- Double Mint 🍃🍃 
-- Version: 0.1.2

-- Requires token blueprint to be loaded in order to run.
-- This minting contract extension is loaded with the token standard. 
-- The default settings mints 1000 of the given token for every 1 $wAR depositted, and 500 of the given token for evry 1 $TRUNk depositted.

-- Steps to install 

-- 1. > .load-blueprint token
-- 2. Save this Double_Mint.lua file to your local system. 
-- 3. Change the Ticker, Logo, and Name in this file to your desired settings
-- 4. > .load path/to/Double_Mint.lua

]]
local json = require('json')
local initialMinted = tonumber(TotalSupply) or 0

-- Define the two minting tokens and their respective multipliers
BuyToken = "xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10"  -- $wAR
BuyToken2 = "OT9qTE2467gcozb2g8R6D6N3nQS94ENcaAIJfUzHCww"  -- $TRUNK

Multiplier1 = 1000  -- Multiplier for BuyToken = 1000 Minted ($wAR has a denomination of 12 the same as the token standard so no conversion necessary)
Multiplier2 = 500000000000   -- Multiplier for BuyToken2 = 500 Minted ($TRUNK has a denomination of 3, so +9 zeros added to convert it. Alter this setting based on the denominator of the token used to mint.)

MaxMint = MaxMint or 1000000000000000000 -- 1,000,000.000000000000
Minted = Minted or initialMinted
Name = "Double Mint"
Ticker = "D-MINT"
Logo = "N05vFiq8CfOH93PtykUbohsV7ON_R3d0Aj2A-ZGwhno"

local function announce(msg, pids)
    Utils.map(function (pid) 
        Send({Target = pid, Data = msg })
    end, pids)
end

-- MINT
Handlers.prepend(
    "Mint",
    function(m)
        return m.Action == "Credit-Notice" and (m.From == BuyToken or m.From == BuyToken2)
    end,
    function(m)
        -- Determine the multiplier based on the token used
        local multiplier = (m.From == BuyToken) and Multiplier1 or Multiplier2

        local requestedAmount = tonumber(m.Quantity)
        local actualAmount = requestedAmount * multiplier

        -- Calculate the remaining mintable amount
        local remainingMintable = MaxMint - Minted

        if remainingMintable <= 0 then
            -- If no tokens can be minted, refund the entire amount
            Send({
                Target = m.From,
                Action = "Transfer",
                Recipient = m.Sender,
                Quantity = tostring(requestedAmount),
                Data = "Mint is Maxed - Refund"
            })
            print('send refund')
            Send({Target = m.Sender, Data = "Mint Maxed, Refund dispatched"})
            return
        end

        -- Calculate the actual amount to mint and the amount to refund
        local mintAmount = math.min(actualAmount, remainingMintable)
        local refundAmount = (actualAmount - mintAmount) / multiplier

        -- Ensure refundAmount is treated as an integer
        refundAmount = tonumber(string.format("%.0f", refundAmount))

        -- Mint the allowable amount
        if mintAmount > 0 then
            assert(type(Balances) == "table", "Balances not found!")
            local prevBalance = tonumber(Balances[m.Sender]) or 0
            Balances[m.Sender] = tostring(math.floor(prevBalance + mintAmount))
            Minted = Minted + mintAmount
            print("Minted " .. tostring(mintAmount) .. " to " .. m.Sender)
            Send({Target = m.Sender, Data = "Successfully Minted " .. mintAmount})
        end

        if refundAmount > 0 then
            -- Send the refund for the excess amount
            Send({
                Target = m.From,
                Action = "Transfer",
                Recipient = m.Sender,
                Quantity = tostring(refundAmount),
                Data = "Mint is Maxed - Partial Refund"
            })
            print('send partial refund of ' .. tostring(refundAmount))
            Send({Target = m.Sender, Data = "Mint Maxed, Partial Refund dispatched"})
        end
    end
)

local function continue(fn) 
    return function (msg) 
        local result = fn(msg)
        if result == -1 then 
            return "continue"
        end
        return result
    end
end
