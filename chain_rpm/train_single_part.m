[model,progress] = train_single_part(name,samples,params,options)
%

%% init model
params.num_parts = 1;
params.len = 1+prod(params.tsize);
model = init_model(params);
model.parent = 0;
model.len = params.len;
model.num_parts = 1;

%% patterns and labels
if params.warp
    warped = warpim(params.maxsize, params.sbin, samples);
end

patterns = cell(length(samples),1);
labels = cell(length(samples),1);

for i = 1:length(samples)
    if params.warp
        im = warped{i}; % cropped and warped img from bbox
        patterns{i}.feat = features(im, params.sbin);
    end
    
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
[model, progress] = ssvm_sgd(patterns, labels, model, param, options);
model = wtomodel(model.w, model);
% visualizemodel(model);

%% cache model
save([params.cachedir name],'model');


%% helper functions
function warped = warpim(siz, sbin, pos)
% Warp positive examples to fit model dimensions.
% Used for training root filters from positive bounding boxes.

pixels = siz * sbin; 
heights = [pos(:).y2]' - [pos(:).y1]' + 1;
widths = [pos(:).x2]' - [pos(:).x1]' + 1;
numpos = length(pos);
warped = cell(numpos,1);
cropsize = (siz+2) * sbin;
for i = 1:numpos
    %fprintflush('%s: warp: %d/%d\n', name, i, numpos);
    im = imread(pos(i).im);
    if size(im, 3) == 1
        im = repmat(im,[1 1 3]);
    end
    padx = sbin * widths(i) / pixels(2);
    pady = sbin * heights(i) / pixels(1);
    x1 = round(pos(i).x1-padx);
    x2 = round(pos(i).x2+padx);
    y1 = round(pos(i).y1-pady);
    y2 = round(pos(i).y2+pady);
    window = subarray(im, y1, y2, x1, x2, 1);
    warped{i} = imresize(window, cropsize, 'bilinear');
end

function B = subarray(A, i1, i2, j1, j2, pad)
% B = subarray(A, i1, i2, j1, j2, pad)
% Extract subarray from array
% pad with boundary values if pad = 1
% pad with zeros if pad = 0

dim = size(A);
B = zeros(i2-i1+1, j2-j1+1, dim(3));
if pad
    for i = i1:i2
        for j = j1:j2
            ii = min(max(i, 1), dim(1));
            jj = min(max(j, 1), dim(2));
            B(i-i1+1, j-j1+1, :) = A(ii, jj, :);
        end
    end
else
    for i = max(i1,1):min(i2,dim(1))
        for j = max(j1,1):min(j2,dim(2))
            B(i-i1+1, j-j1+1, :) = A(i, j, :);
        end
    end
end

