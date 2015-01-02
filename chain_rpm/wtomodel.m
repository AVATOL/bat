function model = wtomodel(w,model,typ)
% w -> model.{bias,node,edge}

if nargin < 3
    typ = 1;
end

w = double(w);

% bias
for i = 1:size(model.bias,1)
    x = model.bias(i,typ);
    s = size(x.w);
    j = x.i:x.i+prod(s)-1;
    model.bias(i,typ).w = reshape(w(j),s);
end

% node
for i = 1:size(model.node,1)
    x = model.node(i,typ);
    s = size(x.w);
    j = x.i:x.i+prod(s)-1;
    model.node(i,typ).w = reshape(w(j),s);
end

% edge
for i = 1:size(model.edge,1)
    for j = 1:size(model.edge,2)
        if isempty(model.edge(i,j).w)
            continue
        end
        x = model.edge(i,j,typ);
        s = size(x.w);
        range = x.i:x.i+prod(s)-1;
        model.edge(i,j,typ).w = reshape(w(range),s);
    end
end

% Debug
w2 = modeltow(model,typ);
assert(isequal(w,w2));
