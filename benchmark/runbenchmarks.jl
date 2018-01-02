using PkgBenchmark

res = benchmarkpkg("ArgCheck")
for (name, group) in res
    println(name)
    display(group)
    println()
end
