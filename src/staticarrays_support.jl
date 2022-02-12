using StaticArrays: StaticArrays, StaticArray, FieldArray, tuple_prod, StaticArrayStyle
import StaticArrays: Size
import Base.Broadcast: instantiate

"""
    StructArrays.staticschema(::Type{<:StaticArray{S, T}}) where {S, T}

The `staticschema` of a `StaticArray` element type is the `staticschema` of the underlying `Tuple`.
```julia
julia> StructArrays.staticschema(SVector{2, Float64})
Tuple{Float64, Float64}
```
The one exception to this rule is `<:StaticArrays.FieldArray`, since `FieldArray` is based on a 
struct. In this case, `staticschema(<:FieldArray)` returns the `staticschema` for the struct 
which subtypes `FieldArray`. 
"""
@generated function StructArrays.staticschema(::Type{<:StaticArray{S, T}}) where {S, T}
    return quote
        Base.@_inline_meta
        return NTuple{$(tuple_prod(S)), T}
    end
end
StructArrays.createinstance(::Type{T}, args...) where {T<:StaticArray} = T(args)
StructArrays.component(s::StaticArray, i) = getindex(s, i)

# invoke general fallbacks for a `FieldArray` type.
@inline function StructArrays.staticschema(T::Type{<:FieldArray})
    invoke(StructArrays.staticschema, Tuple{Type{<:Any}}, T)
end
StructArrays.component(s::FieldArray, i) = invoke(StructArrays.component, Tuple{Any, Any}, s, i)
StructArrays.createinstance(T::Type{<:FieldArray}, args...) = invoke(createinstance, Tuple{Type{<:Any}, Vararg}, T, args...)

@static if isdefined(StaticArrays, :static_combine_axes)
# StaticArrayStyle has no similar defined.
# Convert to `StaticArrayStyle` to return a StaticArray instead.
StructStaticArrayStyle{N} = StructArrayStyle{StaticArrayStyle{N}, N}
@inline function Base.copy(bc::Broadcasted{StructStaticArrayStyle{M}}) where {M}
    bc′ = convert(Broadcasted{StaticArrayStyle{M}}, bc)
    return copy(bc′)
end
function instantiate(bc::Broadcasted{StructStaticArrayStyle{M}}) where {M}
    bc′ = instantiate(convert(Broadcasted{StaticArrayStyle{M}}, bc))
    return convert(Broadcasted{StructStaticArrayStyle{M}}, bc′)
end
function Broadcast._axes(bc::Broadcasted{<:StructStaticArrayStyle}, ::Nothing)
    return StaticArrays.static_combine_axes(bc.args...)
end
Size(::Type{SA}) where {SA<:StructArray} = Size(fieldtype(fieldtype(SA, 1), 1))
StaticArrays.isstatic(::SA) where {SA<:StructArray} = cst(SA) isa StaticArrayStyle
function StaticArrays.similar_type(::Type{SA}, ::Type{T}, s::Size{S}) where {SA<:StructArray, T, S}
    return StaticArrays.similar_type(fieldtype(fieldtype(SA, 1), 1), T, s)
end
end
