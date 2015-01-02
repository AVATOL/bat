function [model,progress] = train_taxon_dpm(name,taxon,samples,part_models,params,options)
%

%% init model
params.num_parts = length(part_models);
model = merge_part_models(part_models, taxon.parent, samples, params);
params.len = model.len;

%% patterns and labels
patterns = cell(length(samples),1);
labels = cell(length(samples),1);

for i = 1:length(samples)
    im = imread(samples(i).im);
    bbox = [samples(i).x1' samples(i).y1' samples(i).x2' samples(i).y2'];
    
    pyra = hog_pyra(im, params); 
    patterns{i}.pyra = pyra;
    labels{i}.bbox = bbox;
    
    % DEBUG
    %patterns{i}.im = im;
end

%% additional for problem structure:
params.lossFn    = @dpm_loss;
params.featureFn = @dpm_featmap;
params.oracleFn  = @dpm_oracle;

%% ssvm optimization
options.lambda = 0.1;
options.num_passes = 200;

[model, progress] = ssvm_sgd(patterns, labels, model, params, options);
model = wtomodel(model.w, model);

%% cache model
save([params.cachedir name],'model');

