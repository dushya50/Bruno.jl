using Distributions: Normal, cdf

"""
price(fin_obj::EuroCallOption, pricing_model::Type{BinomialTree}, tree_depth, r, strike_price, delta)

Computes the value of an European Call Option. 


# Example
```
using Bruno

a_stock = Stock(41; volatility=.3)  # create a widget
a_fin_inst = EuroCallOption(a_stock)  # create an Option
price!(a_fin_inst, BinomialTree; r=.08, strike_price= 40)  # add the binomial Option value to the options values
```
"""
function price!(fin_obj::EuroCallOption, pricing_model::Type{BinomialTree}; tree_depth=3, r=0.05, strike_price, delta=0)
    """ 
    EURO OPTION
    tree_depth = the depth of the tree
    r = rate of return
    strike_price = the strike price in dollars
    delta = intrest rate
    """
    s_0 = last(fin_obj.widget.prices)  
    sigma = fin_obj.widget.volatility
    dt = fin_obj.maturity / tree_depth

    u = exp((r - delta) * dt + sigma * sqrt(dt))  # up movement 
    d = exp((r - delta) * dt - sigma * sqrt(dt))  # down movement
    p = (exp(r * dt) - d) / (u - d)  # risk neutral probability of an up move
    
    c = 0
    # value of the call is a weighted average of the values at each terminal node multiplied by the corresponding probability value
    for k in tree_depth:-1:0
        p_star = (factorial(tree_depth) / (factorial(tree_depth - k) * factorial(k))) * p ^ k * (1 - p) ^ (tree_depth - k)
        term_val = s_0 * u ^ k * d ^ (tree_depth - k)
        c += max(term_val - strike_price, 0) * p_star
    end

    fin_obj.value["Binomial_tree"] = exp(-r * fin_obj.maturity) * c
end

function price!(fin_obj::AmericanCallOption, pricing_model::Type{BinomialTree}, tree_depth, r, strike_price, delta)
    println("currently under dev")
    println(fin_obj)
    0
end

# function b_tree(tree_depth, r, strike_price, time_to_mature, delta)
#     """ 
#     EURO OPTION
#     tree_depth = the depth of the tree
#     r = rate of return
#     sigma = volatility
#     strike_price = the strike price in dollars
#     time_to_mature = time to maturity in years (.5 == 1/2 year) || (1 == 1 year)
#     delta = intrest rate
#     """
#     S0 = 41  # Starting Price  replace me with widget last price
#     sigma = .3  # get sigma from widget price history
#     dt = time_to_mature / tree_depth

#     u = exp((r - delta) * dt + sigma * sqrt(dt))  # up movement 
#     d = exp((r - delta) * dt - sigma * sqrt(dt))  # down movement
#     p = (exp(r * dt) - d) / (u - d)  # risk neutral probability of an up move
    
#     c = 0
#     # value of the call is a weighted average of the values at each node multiplied by the corresponding probability value
#     for k in tree_depth:-1:0
#         p_star = (factorial(tree_depth) / (factorial(tree_depth - k) * factorial(k))) * p ^ k * (1 - p) ^ (tree_depth - k)
#         ST = S0 * u ^ k * d ^ (tree_depth - k)
#         c += max(ST - strike_price, 0) * p_star
#     end

#     exp(-r * time_to_mature) * c
# end

# ----- Price models for call and put options using BlackScholes
function price!(fin_obj::AbstractEuroCall, pricing_model::Type{BlackScholes})
    c1 = log(fin_obj.widget.prices[end] / fin_obj.strike_price)
    a1 = fin_obj.widget.volatility * sqrt(fin_obj.maturity)
    d1 = (c1 + (fin_obj.risk_free_rate + (fin_obj.widget.volatility ^ 2 / 2)) * fin_obj.maturity) / a1
    d2 = d1 - a1 
    value = fin_obj.widget.prices[end] * cdf(Normal(), d1) - fin_obj.strike_price *
        exp(-fin_obj.risk_free_rate * fin_obj.maturity) * cdf(Normal(), d2)

    fin_obj.value["BlackScholes"] = value
end

function price!(fin_obj::AbstractEuroPut, pricing_model::Type{BlackScholes})
    c1 = log(fin_obj.widget.prices[end] / fin_obj.strike_price)
    a1 = fin_obj.widget.volatility * sqrt(fin_obj.maturity)
    d1 = (c1 + (fin_obj.risk_free_rate + (fin_obj.widget.volatility ^ 2/ 2)) * fin_obj.maturity) / a1
    d2 = d1 - a1 
    value = fin_obj.strike_price * exp(-fin_obj.risk_free_rate * fin_obj.maturity) * cdf(Normal(), -d2) - 
        fin_obj.widget.prices[end] * cdf(Normal(), -d1)

    fin_obj.value["BlackScholes"] = value
end

# ----- Price models using Monte Carlo sims
function price!(fin_obj::Option, pricing_model::Type{MonteCarlo{LogDiffusion}};
    n_sims::Int = 100, sim_size::Int = 100)

    dt = fin_obj.maturity / sim_size
    # create the data to be used in the analysis 
    data_input = LogDiffInput(sim_size; initial = fin_obj.widget.prices[end], 
                                volatility = fin_obj.widget.volatility * sqrt(dt),
                                drift = fin_obj.risk_free_rate * dt)
    final_prices = getData(data_input, n_sims)[end,:] 
    # check for exercise or not
    value = sum(payoff(fin_obj, final_prices, fin_obj.strike_price)) / n_sims * 
        exp(-fin_obj.risk_free_rate * fin_obj.maturity)

    fin_obj.value["MC_LogDiffusion"] = value
end


function price!(fin_obj::Option, pricing_model::Type{MonteCarlo{StationaryBootstrap}}; 
                 n_sims::Int)
    
    # create the data to be used in analysis
    returns = [log(1 + (fin_obj.widget.prices[i+1] - fin_obj.widget.prices[i]) / fin_obj.widget.prices[i]) for 
        i in 1:(size(fin_obj.widget.prices)[1] - 1)]

    data_input = BootstrapInput{Stationary}(; input_data = returns, 
                                            n = size(returns)[1])
    data = getData(data_input, n_sims)
    final_prices = [fin_obj.widget.prices[end] * exp(sum(data[:,i]) * fin_obj.maturity) for i in 1:n_sims]
    # calculate the mean present value of the runs
    value = sum(payoff(fin_obj, final_prices, fin_obj.strike_price)) / n_sims * 
        exp(-fin_obj.risk_free_rate * fin_obj.maturity)

    fin_obj.value["MC_StationaryBoot"] = value
end

function payoff(type::CallOption, final_prices, strike_price)
    max.(final_prices .- strike_price, 0) 
end

function payoff(type::PutOption, final_prices, strike_price)
    max.(strike_price .- final_prices, 0)    
end