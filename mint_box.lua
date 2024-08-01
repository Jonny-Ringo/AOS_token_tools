--[[
-- Mint Box 
-- Version: 0.1

-- Requires token blueprint to be loaded in order to run.
-- This minting contract extension is loaded with the token standard. 
-- The default settings mints 1000 of the given token for every 1 $wAR depositted.

-- Steps to install 

-- 1. > .load-blueprint token
-- 2. Save this min_box.lua file to your local system. 
-- 3. Change the Ticker, Logo, and Name in this file to your desired settings
-- 4. > .load path/to/mint_box.lua

]]

local json = require('json')
BuyToken = "xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10" -- $wAR
MaxMint = MaxMint or 1000000000000000000 -- 1,000,000.000000000000
Minted = Minted or 0
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
      local actualAmount = requestedAmount * 1000
      -- if over limit refund difference
      if (Minted + requestedAmount) > MaxMint then
        -- if not enough tokens available send a refund...
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
      assert(type(Balances) == "table", "Balances not found!")
      local prevBalance = tonumber(Balances[m.Sender]) or 0
      Balances[m.Sender] = tostring(math.floor(prevBalance + actualAmount))
      Minted = Minted + actualAmount
      print("Minted " .. tostring(actualAmount) .. " to " .. m.Sender)
      Send({Target = m.Sender, Data = "Successfully Minted " .. actualAmount})
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
  
