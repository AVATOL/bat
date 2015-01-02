function [nodes,edges,filters,resp] = parse_model(model,pyra)

nV = model.num_parts;
assert(nV == length(model.node));

% nodes
nodes = model.node;
for i = 1:nV
    [sizy,sizx,~] = size(nodes(i).w);
    nodes(i).sizy  = sizy;
    nodes(i).sizx  = sizx;
    nodes(i).scale = 0;
    nodes(i).bias  = model.bias(i).w;
    nodes(i).biasI = model.bias(i).i;
end

% edges
edges = model.edge;
for i = 1:nV
    for j = 1:nV
        if isempty(edges(i,j).w)
            continue
        end
		ax = edges(i,j).anchor(1);
		ay = edges(i,j).anchor(2);    
		ds = edges(i,j).anchor(3);
        step = 2^ds;
        virtpady = (step-1)*pyra.pady;
		virtpadx = (step-1)*pyra.padx;
		% starting points (simulates additional padding at finer scales)
		edges(i,j).starty = ay-virtpady;
		edges(i,j).startx = ax-virtpadx;      
		edges(i,j).step   = step;
    end
end

% filters resp
filters = cell(nV,1);
resp = cell(length(pyra.feat),1);
for i = 1:nV
    filters{i} = nodes(i).w;
end

