function model = vec2model(w,model)
% model = vec2model(w,model)

w = double(w);

isOmi = 0;
if isfield(model,'ominode') && isfield(model,'omiedge')
  isOmi = 1;
end

if isOmi == 1
  % ominode
  for i = 1:length(model.bias)
      x = model.bias(i);
      s = size(x.w);
      j = x.i:x.i+prod(s)-1;
      model.ominode(i).w = reshape(w(j),s);
  end

  % omiedge
  for i = 1:length(model.bias)
      x = model.bias(i);
      s = size(x.w);
      j = x.i:x.i+prod(s)-1;
      model.omiedge(i).w = reshape(w(j),s);
  end
end

% Biases
for i = 1:length(model.bias)
    x = model.bias(i);
    s = size(x.w);
    j = x.i:x.i+prod(s)-1;
    model.bias(i).w = reshape(w(j),s);
end

% Deformation parameters
for i = 1:length(model.defs)
  x = model.defs(i);
  s = size(x.w);
  j = x.i:x.i+prod(s)-1;
  model.defs(i).w = reshape(w(j),s);
end

% Filters 
for i = 1:length(model.filters)
  x = model.filters(i);
  s = size(x.w);
  j = x.i:x.i+prod(s)-1;
  model.filters(i).w = reshape(w(j),s);
end

% Debug
w2 = model2vec(model);
assert(isequal(w,w2));
