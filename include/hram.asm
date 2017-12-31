RSSET $ff80

; SampleIndex is the next index into the samples array to write to
SampleIndex rb 1

; SampleBit counts down from 8 every sample, counting the 8 bits we write to each index.
SampleBit rb 1
