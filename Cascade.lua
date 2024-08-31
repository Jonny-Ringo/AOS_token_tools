--[[
-- Cascade
-- Version: 0.1.2

-- Cascade is a minting contract that allows for the issuance of tokens with 
-- an incrementally increasing mint limit per a specified number of blocks. 
-- The default settings start the mint allowance at 100,000 tokens and increases 
-- by 100,000 tokens every 670 blocks(~24hours) until a maximum mint(MaxMint) of 1,000,000 is reached.

-- This minting contract extension is loaded after the token blueprint is loaded. 
-- The default settings mints 1000 of the given token for every 1 $wAR depositted.

-- Steps to install 

-- 1. > .load-blueprint token
-- 2. Save this Cascade.lua file to your local system. 
-- 3. Change the Ticker, Logo, Name, "mintLimitIncrement" Multiplier, and supply numbers in this file to your desired settings.
-- 4. > .load path/to/Cascade.lua

]]


local json = require('json')
local initialMinted = tonumber(TotalSupply) or 0
BuyToken = "xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10" -- $wAR
MaxMint = MaxMint or 1000000000000000000 -- 1,000,000.000000000000
Multiplier = 1000
Minted = Minted or initialMinted
Name = "Cascade"
Ticker = "CAS"
Logo = "VMoNLTDUnfYiXLwAocj88mhT-xOHyXeNrwQfesI_zCA"

local initialBlockHeight = nil
local baseMintLimit = 100000000000000000 -- 100,000.000000000000

local function getCurrentMintLimit(currentHeight)
  local blocksPassed = (currentHeight - initialBlockHeight)
  local mintLimitIncrement = math.floor(blocksPassed / 670) * baseMintLimit
  local currentMintLimit = baseMintLimit + mintLimitIncrement
  return math.min(currentMintLimit, MaxMint)
end

local function announce(msg, pids)
  Utils.map(function (pid) 
    Send({Target = pid, Data = msg })
  end, pids)
end

-- Utility function to check the current mint limit based on the actual current block height
function checkCurrentMintLimit(msg)
  -- Get the current block height from the incoming message
  local currentHeight = tonumber(msg['Block-Height'])

  -- Ensure the initial block height is set (assuming this is done elsewhere)
  if initialBlockHeight == nil then
      print("Error: initialBlockHeight is not set")
      return nil
  end
  
  -- Calculate the current mint limit based on the current block height
  local currentMintLimit = getCurrentMintLimit(currentHeight)
  return "Current Mint Limit at Block Height " .. tostring(currentHeight) .. " is " .. tostring(currentMintLimit)
end

-- MINT
Handlers.prepend(
"Mint",
function(msg)
  return msg.Action == "Credit-Notice" and msg.From == BuyToken
end,
function(msg)
  -- Get the current block height from the message
  local currentHeight = tonumber(msg['Block-Height'])

  -- Set the initial block height if it's not already set
  if initialBlockHeight == nil then
    initialBlockHeight = currentHeight
  end

  -- Calculate the current mint limit based on the block height
  local currentMintLimit = getCurrentMintLimit(currentHeight)

  -- Debugging: Print the current mint limit
  print(checkCurrentMintLimit(msg))  -- This will print the current mint limit

  -- Calculate the remaining mintable amount
  local remainingMintable = math.min(MaxMint - Minted, currentMintLimit - Minted)

  local requestedAmount = tonumber(msg.Quantity)
  local actualAmount = requestedAmount * Multiplier

  if remainingMintable <= 0 then
    -- If no tokens can be minted, refund the entire amount
    Send({
      Target = BuyToken,
      Action = "Transfer",
      Recipient = msg.Sender,
      Quantity = tostring(requestedAmount),
      Data = "Mint is Maxed - Refund"
    })
    print('send refund')
    Send({Target = msg.Sender, Data = "Mint Maxed, Refund dispatched"})
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
    local prevBalance = tonumber(Balances[msg.Sender]) or 0
    Balances[msg.Sender] = tostring(math.floor(prevBalance + mintAmount))
    Minted = Minted + mintAmount
    print("Minted " .. tostring(mintAmount) .. " to " .. msg.Sender)
    Send({Target = msg.Sender, Data = "Successfully Minted " .. mintAmount})
  end

  if refundAmount > 0 then
    -- Send the refund for the excess amount
    Send({
      Target = BuyToken,
      Action = "Transfer",
      Recipient = msg.Sender,
      Quantity = tostring(refundAmount),
      Data = "Mint is Maxed - Partial Refund"
    })
    print('send partial refund of ' .. tostring(refundAmount))
    Send({Target = msg.Sender, Data = "Mint Maxed, Partial Refund dispatched"})
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