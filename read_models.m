% read models to form w

prefix = 'mat';

all_files = dir('.');
png    = arrayfun(@(x) ~isempty(strfind(x.name, prefix)), all_files);
all_files = all_files(logical(png));

sx = 5;
sy = 5;
sz = 32;
w_dim = sx*sy*sz;
w = zeros(w_dim, 1000);
num_tot = 0;

for file = 1:length(all_files)
%     if file == 3 || file == 7
%         continue
%     end
    
    load(all_files(file).name);
    %num_copy = length(allModels);
    num_copy = 1;
    for mdl = 1:num_copy
        %model = allModels{mdl};
        for flt = model.filters
            num_tot = num_tot + 1;
            w(:,num_tot) = reshape(flt.w, [w_dim 1 1]);
        end
    end
end

w = w(:,1:num_tot);



