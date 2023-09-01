export ArbitrarySteppable

"""
    ArbitrarySteppable <: DiscreteTimeDynamicalSystem
    ArbitrarySteppable(
        model, step!, extract_state, extract_parameters, reset_model!;
        isdeterministic = true, set_state = reinit!,
    )

A dynamical system generated by an arbitrary "model" that can be stepped _in-place_
with some function `step!(model)` for 1 step.
The state of the model is extracted by the `extract_state(model) -> u` function
The parameters of the model are extracted by the `extract_parameters(model) -> p` function.
The system may be re-initialized, via [`reinit!`](@ref), with the `reset_model!`
user-provided function that must have the call signature
```julia
reset_model!(model, u, p)
```
given a (potentially new) state `u` and parameter container `p`, both of which will
default to the initial ones in the [`reinit!`](@ref) call.

`ArbitrarySteppable` exists to provide the DynamicalSystems.jl interface to models from
other packages that could be used within the DynamicalSystems.jl library.
`ArbitrarySteppable` follows the [`DynamicalSystem`](@ref) interface with
the following adjustments:

- [`initial_time`](@ref) is always 0, as time counts the steps the model has
  taken since creation or last [`reinit!`](@ref) call.
- [`set_state!`](@ref) is the same as [`reinit!`](@ref) by default.
  If not, the keyword argument `set_state` is a function `set_state(model, u)`
  that sets the state of the model to `u`.
- The keyword `isdeterministic` should be set properly, as it decides whether
  downstream algorithms should error or not.
"""
struct ArbitrarySteppable{M, F, R, ES, EP, U, P, S} <: DiscreteTimeDynamicalSystem
    model::M
    step::F
    reinit::R
    extract_state::ES
    extract_parameters::EP
	t::Base.RefValue{Int}
    u0::U
    p0::P
    isdeterministic::Bool
    set_state::S
end

function ArbitrarySteppable(model, step, extract_state, extract_parameters, reinit;
        isdeterministic = true, set_state = (ds, u) -> reinit(ds, u, current_parameters(ds)),
    )
    p0 = deepcopy(extract_parameters(model))
    u0 = deepcopy(extract_state(model))
    if !(u0 isa AbstractArray{<:Real})
        @warn """
        The state isn't an `AbstractArray{<:Real}` and that may cause problems
        in downstream functions.
        """
    end
    return ArbitrarySteppable(model, step, reinit, extract_state, extract_parameters,
    Ref(0), u0, p0, isdeterministic, set_state)
end

# Extend DynamicalSystems.jl interface
current_state(ds::ArbitrarySteppable) = ds.extract_state(ds.model)
current_parameters(ds::ArbitrarySteppable) = ds.extract_parameters(ds.model)
isdeterministic(ds::ArbitrarySteppable) = ds.isdeterministic
dynamic_rule(ds::ArbitrarySteppable) = ds.step
current_time(ds::ArbitrarySteppable) = ds.t[]
initial_time(ds::ArbitrarySteppable) = 0
SciMLBase.isinplace(ds::ArbitrarySteppable) = true

function SciMLBase.step!(ds::ArbitrarySteppable, n::Int = 1, stop::Bool = true)
    for _ in 1:n
        ds.step(ds.model)
    end
    ds.t[] = ds.t[] + n
    return ds
end

function SciMLBase.reinit!(ds::ArbitrarySteppable, u = initial_state(ds);
        p = current_parameters(ds), t0 = 0, # t0 is not used but required for downstream.
    )
    isnothing(u) && return
    ds.reinit(ds.model, u, p)
    ds.t[] = 0
    return ds
end

function set_state!(ds::ArbitrarySteppable, u)
    ds.set_state(ds.model, u)
    return ds
end

additional_details(ds::ArbitrarySteppable) = [
    "model type" => nameof(typeof(ds.model)),
]