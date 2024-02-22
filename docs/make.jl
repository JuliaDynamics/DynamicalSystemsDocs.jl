using MultiDocumenter

clonedir = ("--temp" in ARGS) ? mktempdir() : joinpath(@__DIR__, "clones")
outpath = mktempdir()
@info """
Cloning packages into: $(clonedir)
Building aggregate site into: $(outpath)
"""

docsmodules = [
    "Core" => [
        ("StateSpaceSets", "numerical handling of sets in state space"),
        ("DynamicalSystemsBase", "infrastructure for programming NLD algorithms"),
    ],
    "Nonlinear Dynamics" => [
        ("PredefinedDynamicalSystems", "predefined dynamical systems used in publications"),
        ("ChaosTools", "various tools for analysing nonlinear and chaotic behaviour"),
        ("Attractors", "find attractors and basins; continuation; tipping"),
    ],
    "Nonlinear Timeseries Analysis" => [
        ("DelayEmbeddings", "optimal (unified/separated) delay coordinate embeddings"),
        ("FractalDimensions", "dozens of estimators for fractal dimensions"),
        ("ComplexityMeasures", "rigorous framework for probabilities, entropies, and other complexity measures"),
        ("TimeseriesSurrogates", "dozes of ways to generate timeseries surrogates and tests hypothesis"),
        ("RecurrenceAnalysis", "recurrence quantification and recurrence network analysis"),
    ],
]

docs = []

function multidocref(package, descr = "")
    name = "$(package).jl"
    if !isempty(descr)
        name *= " - $(descr)"
    end
    MultiDocumenter.MultiDocRef(;
        upstream = joinpath(clonedir, package),
        path = lowercase(package),
        name,
        giturl = "https://github.com/JuliaDynamics/$(package).jl.git",
    )
end

# The main DynamicalSystems.jl package is also the Home of the documentation
push!(docs, multidocref("DynamicalSystems"))

# Now all other packages can be added via a simple nested loop
for groups in docsmodules
    colname = groups[1]
    packages = groups[2]
    multidoccolumn = []
    for (package, descr) in packages
        push!(multidoccolumn, multidocref(package, descr))
    end
    push!(docs, MultiDocumenter.DropdownNav(colname, multidoccolumn))
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

# Deploy
if "deploy" in ARGS
    @warn "Deploying to GitHub" ARGS
    gitroot = normpath(joinpath(@__DIR__, ".."))
    run(`git pull`)
    outbranch = "gh-pages"
    has_outbranch = true
    if !success(`git checkout $outbranch`)
        has_outbranch = false
        if !success(`git switch --orphan $outbranch`)
            @error "Cannot create new orphaned branch $outbranch."
            exit(1)
        end
    end
    for file in readdir(gitroot; join = true)
        endswith(file, ".git") && continue
        rm(file; force = true, recursive = true)
    end
    for file in readdir(outpath)
        cp(joinpath(outpath, file), joinpath(gitroot, file))
    end
    run(`git add .`)
    if success(`git commit -m 'Aggregate documentation'`)
        @info "Pushing updated documentation."
        if has_outbranch
            run(`git push`)
        else
            run(`git push -u origin $outbranch`)
        end
        run(`git checkout main`)
    else
        @info "No changes to aggregated documentation."
    end
else
    @info "Skipping deployment, 'deploy' not passed. Generated files in docs/out." ARGS
    cp(outpath, joinpath(@__DIR__, "out"), force = true)
end
