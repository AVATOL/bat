function [model, progress] = train_inner(name, model, pos, neg, warp, kk, fix_def,...
                iter, lambda, duality_gap, do_line_search, overlap, debug) 
% Train a structured SVM for DPM
% model = initialed model, NOTE: for indivi part, model is init by spos
% pos  = list of positive images with part annotations
% neg  = list of negative images, NOTE: neg is ignored
% warp = 1 uses warped positives
% warp = 0 uses latent positives
% iter = number of passes through data
% lambda  = scale factor for regularization
% overlap = minimum overlap in latent positive search

globals;

if nargin < 13
  lambda = 1;
  duality_gap = 0.1;
  iter = 100;
  do_line_search = 1;
  overlap = 0.6;
  debug = 1;
end

% options structure:
options = [];
options.lambda = lambda;
options.gap_threshold = duality_gap; % duality gap stopping criterion
options.num_passes = iter; % max number of passes through data
options.do_line_search = do_line_search;
options.debug = debug; % for displaying more info (makes code about 3x slower)

% Vectorize the model
%len  = sparselen(model);
len = model.len;

% patterns and labels
if warp
  warped = warppos(name, model, pos);
end

patterns = cell(length(pos),1);
labels = cell(length(pos),1);

for i = 1:length(pos)
  if warp
    im = warped{i};
    feat = features(im, model.sbin);
    patterns{i}.feat = feat;
  end
  
  im = imread(pos(i).im);
  bbox = [pos(i).x1' pos(i).y1' pos(i).x2' pos(i).y2'];
  if warp
    [im, bbox] = cropposwarp(im, bbox); % NOTE: for speeding up training, may hurt performance
  end
  
  pyra = featpyramid(im, model); 
  patterns{i}.pyra = pyra;
  %bbox = [reshape(bbox',1,4*length(pos(i).x1)) 1 0];
  labels{i}.bbox = bbox;
end

components = modelcomponents(model,pyra);
parts = components{1}; % TODO: support multiple components

% create problem structure:
param = [];     
param.patterns  = patterns;
param.labels    = labels; 
param.lossFn    = @detect_loss;
param.oracleFn  = @detect_oracle;
param.featureFn = @detect_featuremap;
param.parts     = parts;
param.warp      = warp;
param.len       = len;
param.overlap   = overlap;
param.overlap1   = overlap / 2;
param.thresh    = 0;
param.latent    = ~warp;
param.fix_def   = fix_def;

[model, progress] = solverSSG(model, param, options, kk);
model = vec2model(model.w, model);

% TODO: set model.thresh by w^T x

% visualizemodel(model);
% % cache model
% save([cachedir name '_model_' num2str(t)], 'model');

