function [w,wreg,w0,noneg] = model2vec(model)
% [w,wreg,w0,nonneg] = model2vec(model)

w     = zeros(model.len,1);
w0    = zeros(model.len,1);
wreg  = ones(model.len,1);
noneg = uint32([]);

isOmi = 0;
if isfield(model,'ominode') && isfield(model,'omiedge')
  isOmi = 1;
end

if isOmi == 1
  for x = model.ominode
    j = x.i:x.i+numel(x.w)-1;
    w(j) = x.w;
  end

  for x = model.omiedge
    j = x.i:x.i+numel(x.w)-1;
    w(j) = x.w;
  end
end

for x = model.bias
  j = x.i:x.i+numel(x.w)-1;
  w(j) = x.w;
end

for x = model.filters
  j = x.i:x.i+numel(x.w)-1;
  w(j) = x.w;
end

for x = model.defs
  j = x.i:x.i+numel(x.w)-1;
  w(j) = x.w;
  % Enforce minimum quadratic deformation costs of .01
  j = [j(1) j(3)];
  w0(j) = .01;
  noneg = [noneg uint32(j)];
end

% Regularize root biases differently
for i = 1:length(model.components)
  b = model.components{i}(1).biasid;
  x = model.bias(b);
  j = x.i:x.i+numel(x.w)-1;
  wreg(j) = .01;  
end
