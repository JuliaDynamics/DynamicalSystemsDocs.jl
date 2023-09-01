using MultiDocumenter

clonedir = ("--temp" in ARGS) ? mktempdir() : joinpath(@__DIR__, "clones")
outpath = mktempdir()
@info """
Cloning packages into: $(clonedir)
Building aggregate site into: $(outpath)
"""


docsmodules = [
    "Core" => ["StateSpaceSets", "DynamicalSystemsBase"],
    "Nonlinear Dynamics" => ["PredefinedDynamicalSystems", "ChaosTools", "Attractors"],
    "Nonlinear Timeseries Analysis" =>
        ["DelayEmbeddings", "FractalDimensions",
        "ComplexityMeasures", "TimeseriesSurrogates", "RecurenceAnalysis"],
]

docs = []

# The main DynamicalSystems.jl package is also the Home of the documentation
push!(docs,
    MultiDocumenter.MultiDocRef(
        upstream = joinpath(clonedir, "DynamicalSystems"),
        path = "dynamicalsystems",
        name = "DynamicalSystems.jl", # TODO: Maybe name "Home"?
        giturl = "https://github.com/JuliaDynamics/DynamicalSystems.jl.git",
    ),
)

# Now all other packages can be added via a simple nested loop
for groups in docsmodules
    colname = groups[1]
    packages = groups[2]
    multidoccolumn = []
    for package in packages
        push!(multidoccolumn,
        MultiDocumenter.MultiDocRef(
            upstream = joinpath(clonedir, "DynamicalSystems"),
            path = lowercase(package),
            name = "$(package).jl",
            giturl = "https://github.com/JuliaDynamics/$(package).jl.git",
        ),
    )
    end
    push!(docs, MultiDocumenter.DropdownNav("colname", multidoccolumn))
end

# Build the documentation
MultiDocumenter.make(
    outpath,
    docs;
    search_engine = MultiDocumenter.SearchConfig(
        index_versions = ["stable"],
        engine = MultiDocumenter.FlexSearch,
    ),
    rootpath = "/DynamicalSystemsDocs.jl/",
    # canonical_domain = "https://juliadynamics.github.io/",
    # sitemap = true,
)