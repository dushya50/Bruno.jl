module Instruments
using Statistics: var

# export from widgets
export Widget, Stock, Commodity, Bond
# exports from financial_instruments
export FinancialInstrument, Option, CallOption, PutOption, Future
    
include("widgets.jl")
include("financial_instruments.jl")

end #module