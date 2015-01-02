function [nodes,edges,filters,resp] = parse_model(model,pyra)

nC = length(model);
nodes = cell(nC,1);
edges = cell(nC,1);

for c = 1:nC % components
    % nodes
    nodes{c} = model(c).node;
    [nV,nT] = size(nodes{c});
    for i = 1:nV
        for t = 1:nT
            [sizy,sizx,~] = size(nodes{c}(i,t).w);
            nodes{c}(i,t).sizy  = sizy;
            nodes{c}(i,t).sizx  = sizx;
            nodes{c}(i,t).scale = 0;
            nodes{c}(i,t).bias  = model(c).bias(i,t).w;
            nodes{c}(i,t).biasI = model(c).bias(i,t).i;
        end
    end

    % edges
    edges{c} = model(c).edge;
    for i = 1:nV
        for j = 1:nV
            if isempty(edges{c}(i,j,1).w)
                continue
            end
            for t = 1:nT
			    ax = edges{c}(i,j,t).anchor(1);
			    ay = edges{c}(i,j,t).anchor(2);    
			    ds = edges{c}(i,j,t).anchor(3);
                step = 2^ds;
                virtpady = (step-1)*pyra.pady;
			    virtpadx = (step-1)*pyra.padx;
			    % starting points (simulates additional padding at finer scales)
			    edges{c}(i,j,t).starty = ay-virtpady;
			    edges{c}(i,j,t).startx = ax-virtpadx;      
			    edges{c}(i,j,t).step   = step;
            end
        end
    end
end

% filters resp
filters = cell(nC,1);
resp = cell(nC,1);
for c = 1:nC
    [nV,nT] = size(nodes{c});
    filters{c} = cell(nV,nT);
    for i = 1:nV
        for t = 1:nT
            filters{c}{i,t} = nodes{c}(i,t).w;
        end
    end

    resp{c} = cell(length(pyra.feat),1);
end

if nC == 1
    nodes = nodes{1};
    edges = edges{1};
    filters = filters{1};
    resp = resp{1};
end
