function exportpart(name, nparts)

for i = 1:nparts
  export_singlepart(name,i);
end

close all

function export_singlepart(name,pid)

load(['cache_old/' name '_part_' num2str(pid) '_mix_1'])

visualizemodel(model)

filename = [name num2str(pid)];
export_fig(filename, '-eps')

%close all