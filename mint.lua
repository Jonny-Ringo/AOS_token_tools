--[[
-- Mint 🍃 
-- Version: 0.1.4

-- Requires token blueprint to be loaded in order to run.
-- This minting contract extension is loaded with the token standard. 
-- The default settings mints 1000 of the given token for every 1 $wAR depositted.

-- Steps to install 

-- 1. > .load-blueprint token
-- 2. Save this mint.lua file to your local system. 
-- 3. Change the Ticker, Logo, and Name in this file to your desired settings
-- 4. > .load path/to/mint.lua

]]

local json = require('json')
local initialMinted = tonumber(TotalSupply) or 0
BuyToken = "xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10" -- $wAR
MaxMint = MaxMint or 1000000000000000000 -- 1,000,000.000000000000
Multiplier = 1000
Minted = Minted or initialMinted
Name = "Mint"
Ticker = "MINT"
Logo = "mw4YSN8r581cqIHFgzAtrbOB4JqFzGCDI6yhcdqT0po"


local function announce(msg, pids)
    Utils.map(function (pid) 
      Send({Target = pid, Data = msg })
    end, pids)
  end
  
  
  -- MINT
Handlers.prepend(
  "Mint",
  function(m)
    return m.Action == "Credit-Notice" and m.From == BuyToken
  end,
  function(m) -- Mints tokens at 1:1000 for the payment token
    local requestedAmount = tonumber(m.Quantity)
    local actualAmount = requestedAmount * Multiplier

    -- Calculate the remaining mintable amount
    local remainingMintable = MaxMint - Minted

    if remainingMintable <= 0 then
      -- If no tokens can be minted, refund the entire amount
      Send({
        Target = BuyToken,
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
    local refundAmount = (actualAmount - mintAmount) / Multiplier

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
        Target = BuyToken,
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
