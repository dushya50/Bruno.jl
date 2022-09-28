using Bruno
using BenchmarkTools
using DataFrames
using CSV
using Dates
using Base.Threads

function collect_functions(x::Module)
    results = String[]
    for i in names(x; all=false, imported=false)
        a_string = String(i)
        push!(results, String(a_string))
    end
    return results
end

function main()
    list_of_functions = collect_functions(Bruno)

    # Deletes things that dont need to be tested like "Bruno", "Widget
    deleteat!(list_of_functions, findall(x->x=="Bruno", list_of_functions))
    deleteat!(list_of_functions, findall(x->x=="Widget", list_of_functions))
    
    # Set up
    df = DataFrame(functions=list_of_functions)  # Set up the df
    generic_arguments = Dict(:prices => [151.76, 150.77, 150.43, 152.74, 153.72, 156.90, 154.48, 150.70, 152.37, 155.31, 153.84], 
                                :volatility => .05, 
                                :name => "a_name",
                                :to_produce => 50)

    # Start calling the known functions
    known_functions = [profile_stock, profile_commodity, profile_factory, profile_bond]  # <--- add the head of a function here after writing it
    results = Dict()

    lk = ReentrantLock()
    lk2 = ReentrantLock()
    @threads for a_function in known_functions
        print()
        name, elapsed = a_function(generic_arguments, lk2)
        println(name, " ", elapsed)
        
        lock(lk) do 
            results[name] = elapsed
        end
    end

    # update df with results
    the_keys = collect(keys(results))
    new_df = DataFrame(functions=the_keys, time=[results[i] for i in the_keys])

    leftjoin!(df, new_df, on=:functions)
    replace!(df.time, missing => -1);

    # Save csv to Fi
    CSV.write("results/" * Dates.format(now(), "yyyy-mm-dd_HH_MM_SS") * ".csv", df)
    
end

"""
Function tests below. Each function returns the name of the functions it
is testing in the first postion and the time the profiler takes in the
second.

As a note try to test the worst case. As an example if we give stock 
all struct variables it wont have to calculate the var. 

Functions calls written:
    Stock
    Commodity
    BondBond
    Bond
    factory

Functions calls to be written:
    AbstractAmericanCall    
    AbstractAmericanPut     
    AbstractEuroCall        
    AbstractEuroPut         
    AmericanCallOption      
    AmericanPutOption       
    BinomialTree            
    BlackScholes                                
    BootstrapInput          
    CallOption              
    CircularBlock           
    CircularBlockBootstrap               
    DataGenInput            
    EuroCallOption          
    EuroPutOption           
    FinancialInstrument     
    Future                  
    LogDiffInput            
    LogDiffusion            
    MonteCarlo              
    MonteCarloModel         
    MovingBlock             
    Option                  
    PutOption               
    Stationary              
    StationaryBootstrap                        
    TSBootMethod                              
    b_tree                  
    data_gen_input                           
    getData                 
    getTime                 
    opt_block_length        
    price!                  
"""

function profile_stock(kwargs, a_lock)
    prices = kwargs[:prices]

    lock(a_lock) do 
        timed = @benchmark Stock($prices);
        return ("Stock", mean(timed).time)
    end
end

function profile_commodity(kwargs, a_lock)
    prices = kwargs[:prices]

    lock(a_lock) do 
        timed = @benchmark Commodity($prices);
        return ("Commodity", mean(timed).time)
    end
end

function profile_bond(kwargs, a_lock)
    prices = kwargs[:prices]

    lock(a_lock) do 
        timed = @benchmark Bond($prices);
        return ("Bond", mean(timed).time)
    end
end

function profile_factory(kwargs, a_lock)
    a_stock = Stock(kwargs[:prices])
    
    lock(a_lock) do 
        timed = @benchmark factory($a_stock, Stationary, $kwargs[:to_produce])
        return ("factory", mean(timed).time)
    end
end