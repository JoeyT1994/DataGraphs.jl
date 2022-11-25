abstract type AbstractDataGraph{V,VD,ED} <: AbstractGraph{V} end

# Minimal interface
underlying_graph(::AbstractDataGraph) = not_implemented()
underlying_graph_type(::Type{<:AbstractDataGraph}) = not_implemented()
vertex_data(::AbstractDataGraph) = not_implemented()
vertex_data_type(::Type{<:AbstractDataGraph}) = not_implemented()
edge_data(::AbstractDataGraph) = not_implemented()
edge_data_type(::Type{<:AbstractDataGraph}) = not_implemented()

# Derived interface
edgetype(G::Type{<:AbstractDataGraph}) = edgetype(underlying_graph_type(G))
is_directed(G::Type{<:AbstractDataGraph}) = is_directed(underlying_graph_type(G))
underlying_graph_type(graph::AbstractDataGraph) = typeof(underlying_graph(graph))
vertex_data_type(graph::AbstractDataGraph) = vertex_data_type(typeof(graph))
edge_data_type(graph::AbstractDataGraph) = edge_data_type(typeof(graph))

# TODO: delete, defined for AbstractGraph{V}?
vertextype(G::Type{<:AbstractDataGraph}) = vertextype(underlying_graph_type(G))
vertextype(graph::AbstractDataGraph) = vertextype(typeof(graph))

# Graphs overloads
for f in [
  :add_edge!,
  :add_vertex!,
  :adjacency_matrix,
  :bfs_parents,
  :bfs_tree,
  :dfs_parents,
  :dfs_tree,
  :edges,
  :edgetype,
  :eltype,
  :has_edge,
  :has_vertex,
  :is_connected,
  :is_cyclic,
  :is_directed,
  :is_strongly_connected,
  :is_weakly_connected,
  :ne,
  :neighbors,
  :nv,
  :vertices,
]
  @eval begin
    function $f(graph::AbstractDataGraph, args...; kwargs...)
      return $f(underlying_graph(graph), args...; kwargs...)
    end
  end
end

@traitfn directed_graph(graph::AbstractDataGraph::IsDirected) = graph

@traitfn function directed_graph(graph::AbstractDataGraph::(!IsDirected))
  digraph = directed_graph(typeof(graph))(directed_graph(underlying_graph(graph)))
  for v in vertices(graph)
    # TODO: Only loop over `keys(vertex_data(graph))`
    if isassigned(graph, v)
      digraph[v] = graph[v]
    end
  end
  for e in edges(graph)
    # TODO: Only loop over `keys(edge_data(graph))`
    # TODO: Are these needed?
    add_edge!(digraph, e)
    add_edge!(digraph, reverse(e))
    if isassigned(graph, e)
      digraph[e] = graph[e]
    end
    if isassigned(graph, reverse(e))
      # TODO: Use a function `arrange` like in MetaGraphsNext:
      # https://github.com/JuliaGraphs/MetaGraphsNext.jl/blob/1539095ee6088aba0d5b1cb057c339ad92557889/src/metagraph.jl#L75-L80
      # to sort the vertices, only directed graphs should have store data
      # in both edge directions. Also, define `reverse_data_direction` as a function
      # stored in directed AbstractDataGraph types (which by default returns nothing,
      # indicating not to automatically store data in both directions)
      digraph[reverse(e)] = reverse_direction(graph[e])
    end
  end
  return digraph
end

# Union the vertices and edges of the graphs and
# merge the vertex and edge metadata.
function union(
  graph1::AbstractDataGraph,
  graph2::AbstractDataGraph;
  merge_data=merge,
  merge_vertex_data=merge_data,
  merge_edge_data=merge_data,
)
  underlying_graph_union = union(underlying_graph(graph1), underlying_graph(graph2))
  vertex_data_merge = merge_vertex_data(vertex_data(graph1), vertex_data(graph2))
  edge_data_merge = merge_edge_data(edge_data(graph1), edge_data(graph2))
  # TODO: Convert to `promote_type(typeof(graph1), typeof(graph2))`
  return DataGraph(underlying_graph_union, vertex_data_merge, edge_data_merge)
end

function rename_vertices(
  f::Function,
  graph::AbstractDataGraph,
)
  renamed_underlying_graph = rename_vertices(f, underlying_graph(graph))
  # TODO: Base the ouput type on `typeof(graph)`, for example:
  # convert_vertextype(eltype(renamed_vertices), typeof(graph))(renamed_underlying_graph)
  renamed_graph = DataGraph{vertex_data_type(graph),edge_data_type(graph)}(renamed_underlying_graph)
  for v in keys(vertex_data(graph))
    renamed_graph[f(v)] = graph[v]
  end
  for e in keys(edge_data(graph))
    renamed_graph[rename_vertices(f, e)] = graph[e]
  end
  return renamed_graph
end

# # https://en.wikipedia.org/wiki/Disjoint_union
# function disjoint_union(
#   graph1::AbstractDataGraph,
#   graph2::AbstractDataGraph;
#   subscripts=(1, 2),
# )
#   renamed_graph1 = rename_vertices(v -> (v, subscripts[1]), graph1)
#   renamed_graph2 = rename_vertices(v -> (v, subscripts[2]), graph2)
#   return union(renamed_graph1, renamed_graph2)
# end

function rem_vertex!(graph::AbstractDataGraph, vertex)
  neighbor_edges = incident_edges(graph, vertex)
  # unset!(vertex_data(graph), to_vertex(graph, vertex...))
  unset!(vertex_data(graph), vertex)
  for neighbor_edge in neighbor_edges
    unset!(edge_data(graph), neighbor_edge)
  end
  rem_vertex!(underlying_graph(graph), vertex)
  return graph
end

function rem_edge!(graph::AbstractDataGraph, edge)
  unset!(edge_data(graph), edge)
  rem_edge!(underlying_graph(graph), edge)
  return graph
end

# Fix ambiguity with:
# Graphs.neighbors(graph::AbstractGraph, v::Integer)
neighbors(graph::AbstractDataGraph, v::Integer) = neighbors(underlying_graph(graph), v)

# Fix ambiguity with:
# Graphs.bfs_tree(graph::AbstractGraph, s::Integer; dir)
function bfs_tree(graph::AbstractDataGraph, s::Integer; kwargs...)
  return bfs_tree(underlying_graph(graph), tuple(s); kwargs...)
end

# Fix ambiguity with:
# Graphs.dfs_tree(graph::AbstractGraph, s::Integer; dir)
function dfs_tree(graph::AbstractDataGraph, s::Integer; kwargs...)
  return dfs_tree(underlying_graph(graph), tuple(s); kwargs...)
end

# # Vertex or Edge trait
# struct VertexIndex <: IndexType end
# struct EdgeIndex <: IndexType end
# 
# # TODO: To allow the syntax `g[1, 1]` as a shorthand for the index `g[(1, 1)]`,
# # define `IndexType(graph::AbstractGraph, args...) = IndexType(graph::AbstractGraph, args)`.
# function IndexType(graph::AbstractGraph, index)
#   return error("$index doesn't represent a vertex or an edge for graph:\n$graph.")
# end
# IndexType(graph::AbstractGraph{V}, ::V) where {V} = VertexIndex()
# IndexType(graph::AbstractGraph, ::AbstractEdge) = EdgeIndex()
# IndexType(graph::AbstractGraph, ::Pair) = EdgeIndex()
# 
# # Handles multi-dimensional indexing.
# # XXX: Maybe only define for `NamedDimDataGraph`?
# IndexType(graph::AbstractGraph, ::Any...) = VertexIndex()
# 
# data(::VertexIndex, graph::AbstractDataGraph) = vertex_data(graph)
# data(::EdgeIndex, graph::AbstractDataGraph) = edge_data(graph)
# 
# # Slicing is assumed to slice vertices (vertex-induced subgraph)
# data(::SliceIndex, graph::AbstractDataGraph) = vertex_data(graph)
# 
# index_type(::VertexIndex, graph::AbstractDataGraph, v) = eltype(graph)(v)
# index_type(::EdgeIndex, graph::AbstractDataGraph, e) = edgetype(graph)(e)
# 
# # Handles multi-dimensional indexing.
# # XXX: Maybe only define for `NamedDimDataGraph`?
# function index_type(::VertexIndex, graph::AbstractDataGraph, v1, v2, vs...)
#   return eltype(graph)(tuple(v1, v2, vs...))
# end

function map_vertex_data(f, graph::AbstractDataGraph; vertices=nothing)
  graph′ = copy(graph)
  vs = isnothing(vertices) ? Graphs.vertices(graph) : vertices
  for v in vs
    graph′[v] = f(graph[v])
  end
  return graph′
end

function map_edge_data(f, graph::AbstractDataGraph; edges=nothing)
  graph′ = copy(graph)
  es = isnothing(edges) ? Graphs.edges(graph) : edges
  for e in es
    graph′[e] = f(graph[e])
  end
  return graph′
end

function map_data(f, graph::AbstractDataGraph; vertices=nothing, edges=nothing)
  graph = map_vertex_data(f, graph; vertices)
  return map_edge_data(f, graph; edges)
end

# Data access
# function getindex(ve::IndexType, graph::AbstractDataGraph, index)
#   # return getindex(data(ve, graph), index_type(ve, graph, index...))
#   return getindex(data(ve, graph), index)
# end

function getindex(graph::AbstractDataGraph, index)
  return vertex_data(graph)[index]
end

function get(graph::AbstractDataGraph, index, default)
  return get(vertex_data(graph), index, default)
end

function getindex(graph::AbstractDataGraph, index::AbstractEdge)
  return edge_data(graph)[index]
end

# Support syntax `g[v1 => v2]`
function getindex(graph::AbstractDataGraph, index::Pair)
  return graph[edgetype(graph)(index)]
end

function get(graph::AbstractDataGraph, index::AbstractEdge, default)
  return get(edge_data(graph), index, default)
end

function get(graph::AbstractDataGraph, index::Pair, default)
  return get(graph, edgetype(graph)(index), default)
end

# Support syntax `g[1, 2] = g[(1, 2)]`
function getindex(graph::AbstractDataGraph, i1, i2, i...)
  return graph[(i1, i2, i...)]
end

function isassigned(graph::AbstractDataGraph, index)
  return isassigned(vertex_data(graph), index)
end

function isassigned(graph::AbstractDataGraph, index::AbstractEdge)
  return isassigned(edge_data(graph), index)
end

function isassigned(graph::AbstractDataGraph, index::Pair)
  return isassigned(graph, edgetype(graph)(index))
end

# function isassigned(graph::AbstractDataGraph, index)
#   return isassigned(IndexType(graph, index), graph, index)
# end
# function isassigned(ve::IndexType, graph::AbstractDataGraph, index)
#   # return isassigned(data(ve, graph), index_type(ve, graph, index))
#   return isassigned(data(ve, graph), index)
# end

function setindex!(graph::AbstractDataGraph, x, index)
  set!(vertex_data(graph), index, x)
  return graph
end

# TODO: Store `reverse_direction` inside `AbstractDataGraph`.
reverse_direction(x) = x
function setindex!(graph::AbstractDataGraph, x, index::AbstractEdge)
  set!(edge_data(graph), index, x)
  set!(edge_data(graph), reverse(index), reverse_direction(x))
  return graph
end

function setindex!(graph::AbstractDataGraph, x, index::Pair)
  graph[edgetype(graph)(index)] = x
  return graph
end

# Support syntax `g[1, 2] = g[(1, 2)]`
function setindex!(graph::AbstractDataGraph, x, i1, i2, i...)
  graph[(i1, i2, i...)] = x
  return graph
end

## function setindex!(ve::VertexIndex, graph::AbstractDataGraph, x, index)
##   @assert has_vertex(graph, index)
##   # set!(data(ve, graph), index_type(ve, graph, index...), x)
##   set!(data(ve, graph), index, x)
##   return graph
## end

# Induced subgraph
## function getindex(g::AbstractDataGraph, sub_vertices::Vector)
##   return induced_subgraph(g, sub_vertices)[1]
## end

## function _induced_subgraph(graph::AbstractDataGraph, vlist_or_elist)
##   parent_induced_subgraph = induced_subgraph(underlying_graph(graph), vlist_or_elist)
##   # TODO: Get the data of the subgraph.
##   return not_implemented()
## end

## function induced_subgraph(graph::AbstractDataGraph, vlist_or_elist)
##   return _induced_subgraph(graph, vlist_or_elist)
## end

# fix ambiguity error:
# ERROR: MethodError: induced_subgraph(::ITensorNetwork{Int64}, ::Vector{Int64}) is ambiguous. Candidates:
# induced_subgraph(g::T, vlist::AbstractVector{U}) where {U<:Integer, T<:Graphs.AbstractGraph} in Graphs at /home/mfishman/.julia/packages/Graphs/Mih78/src/operators.jl:639
# induced_subgraph(graph::ITensorNetworks.DataGraphs.AbstractDataGraph, vlist_or_elist) in ITensorNetworks.DataGraphs at /home/mfishman/.julia/dev/ITensorNetworks/src/DataGraphs/src/DataGraphs.jl:96
## function induced_subgraph(
##   graph::AbstractDataGraph, vlist_or_elist::AbstractVector{<:Integer}
## )
##   return _induced_subgraph(graph, vlist_or_elist)
## end

# Overload this to have custom behavior for the data in different directions,
# such as complex conjugation.
# function setindex!(ve::EdgeIndex, graph::AbstractDataGraph, x, args...)
#   i = index_type(ve, graph, args...)
#   @assert has_edge(graph, i)
#   # Handles edges in both directions. Assumes data is the same, potentially
#   # up to `reverse_direction(x)`.
#   set!(data(ve, graph), i, x)
#   set!(data(ve, graph), reverse(i), reverse_direction(x))
#   return graph
# end

#
# Printing
#

function show(io::IO, mime::MIME"text/plain", graph::AbstractDataGraph)
  println(io, "$(typeof(graph)) with $(nv(graph)) vertices:")
  show(io, mime, vertices(graph))
  println(io, "\n")
  println(io, "and $(ne(graph)) edge(s):")
  for e in edges(graph)
    show(io, mime, e)
    println(io)
  end
  println(io)
  println(io, "with vertex data:")
  show(io, mime, vertex_data(graph))
  println(io)
  println(io)
  println(io, "and edge data:")
  show(io, mime, edge_data(graph))
  return nothing
end

show(io::IO, graph::AbstractDataGraph) = show(io, MIME"text/plain"(), graph)
