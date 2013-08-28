% runExperiments.m

allList = {'A', 'G', 'M1', 'M2', 'N', 'S', 'T'};

for si = 1:length(allList)
    if si == 3, continue; end % DEBUG code
    sources = {allList{si}};
    targets = setdiff(allList, sources);
    runSIFTflow(sources, targets);
end