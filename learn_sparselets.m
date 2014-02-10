function [S, model] = learn_sparselets(d, m, L0, model)
% [S, model] = LEARN_SPARSELETS(d, m, L0, model)
%
% Learns a dictionary of sparselets (S) and reconstructive activation
% vectors (stored in model.alpha).
% 
% d       Number of sparselets (dictionary size)
% m       Sparselet length (block dimension)
% L0      Sparsity constraint
% model   Linear classifiers stored as columns of model.w
%
% Copyright (C) 2012-13 Ross Girshick
%
% This file is part of das-sparselets, available under the terms of the
% GNU GPLv2, or (at your option) any later version.

sz = size(model.w);
assert(mod(sz(1),m) == 0);
num_blocks = sz(1)/m;

X = reshape(model.w, [m num_blocks*sz(2)]);

param.K = d;
param.mode = 3;
param.lambda = L0;
param.numThreads = -1;
param.iter = 100;

S = mexTrainDL(X, param);

alpha = get_alpha(X, S, L0);
model.alpha = reshape(alpha, [num_blocks*d sz(2)]);


% ------------------------------------------------------------------------
function alpha = get_alpha(X, S, L0)
% ------------------------------------------------------------------------
param.L = L0;
param.eps = 0.0001;

alpha = mexOMP(X, S, param);
if sum(abs(alpha) > 0) > L0
  error('not using <= L elements');
end
R = mean(0.5*sum((X - S*alpha).^2));
fprintf('objective function: %f\n',R);
