function w = modeltow(model,typ)
% model.{bias,node,edge} -> w

if nargin < 2
    typ = 1;
end

w = zeros(model.len,1); % TODO: m.s. model.len correct

% bias
for i = 1:size(model.bias,1)
    x = model.bias(i,typ);
    j = x.i:x.i+numel(x.w)-1;
    w(j) = x.w;
end

% node
for i = 1:size(model.node,1)
    x = model.node(i,typ);
    j = x.i:x.i+numel(x.w)-1;
    w(j) = x.w;
end

% edge
for i = 1:size(model.edge,1)
    for p = 1:size(model.edge,2)
        x = model.edge(i,p,typ);
        j = x.i:x.i+numel(x.w)-1;
        w(j) = x.w;
    end
end

