local CustomNetLib = {}

function CustomNetLib.ConvertToRaw(sentence: string)
    -- 1. Calculate the metrics using string patterns
    local totalLetters = string.len(sentence)
    
    -- Count punctuation characters (like commas, periods, exclamation points)
    local _, punctuationCount = string.gsub(sentence, "[%p]", "")
    
    -- 2. Allocate exact buffer space: 1 byte (Letters) + 1 byte (Punctuation) + String Bytes
    local totalRequiredSize = 1 + 1 + totalLetters
    local b = buffer.create(totalRequiredSize)
    
    -- 3. Sequentially write the data to the raw packet
    buffer.writeu8(b, 0, totalLetters)       -- Position 0: Letter count
    buffer.writeu8(b, 1, punctuationCount)   -- Position 1: Punctuation count
    buffer.writestring(b, 2, sentence)       -- Position 2 onwards: The actual sentence
    
    return b
end

-- The Reading Module (Used by your script on the receiving end to decode it)
function CustomNetLib.DecodeRaw(b: buffer)
    local totalLetters = buffer.readu8(b, 0)
    local punctuationCount = buffer.readu8(b, 1)
    local sentence = buffer.readstring(b, 2, totalLetters)
    
    return {
        Letters = totalLetters,
        Punctuation = punctuationCount,
        Text = sentence
    }
end

return CustomNetLib
