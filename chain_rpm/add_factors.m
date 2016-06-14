function model = add_factors(params, model, varargin)
% TODO: support adding with DAG

pmodels = [];
trains = [];
is_node = 0;
is_edge = 0;

% parse argins
assert(mod(nargin,2) == 0);
for i = 1:2:nargin-2
    if strcmp(varargin{i}, 'node')
        is_node = 1;
        pmodels = varargin{i+1}; % existing indiv model only for node
    elseif strcmp(varargin{i}, 'edge')
        is_edge = 1;
        trains = varargin{i+1};
        assert(~isempty(trains));
    else
        error('add_factors(): unknown adding type!\n');
    end
end

if ~isfield(model,'len')
    model.len = 0;
end

num_parts = model.num_parts;
parent = model.parent;

if is_node
    if isempty(pmodels)
        for k = 1:num_parts
            model = add_node(model, params.tsize, k);
        end
    else 
        assert(length(pmodels) == num_parts);
        for k = 1:num_parts
            model = add_node(model, params.tsize, k, pmodels{k}.bias, pmodels{k}.node);
        end
    end
end

if is_edge
    df = data_def(trains, params.maxsize);

    for k = 1:num_parts
        par = parent(k);
        if par
            model = add_edge(model, df, k, par);
        end
    end
end


%% helper functions
function model = add_node(model, tsize, k, bias, node)

if nargin < 4
    bias.w = 0;
    node.w = zeros(tsize);
end

model.bias(k).w = bias.w;
model.bias(k).i = model.len + 1;
model.len = model.len + 1;

model.node(k).w = node.w;
model.node(k).i = model.len + 1;
model.len = model.len + prod(tsize);


function model = add_edge(model, df, k, par, edge)

if nargin < 5
    edge.w = [0.01 0 0.01 0];
    x = mean(df{k}(:,1) - df{par}(:,1));
    y = mean(df{k}(:,2) - df{par}(:,2));
    edge.anchor = round([x+1 y+1 0]);
end

model.edge(k,par).w = edge.w;
model.edge(k,par).i = model.len + 1;
model.edge(k,par).anchor = edge.anchor;
model.len = model.len + 4;


function deffeat = data_def(trains, maxsize)
% get absolute trainsitions of parts with respect to HOG cell

width  = zeros(1,length(trains));
height = zeros(1,length(trains));
points = zeros(size(trains(1).point,1),size(trains(1).point,2),length(trains));

for n = 1:length(trains)
    width(n)  = trains(n).x2(1) - trains(n).x1(1) + 1;
    height(n) = trains(n).y2(1) - trains(n).y1(1) + 1;
    points(:,:,n) = trains(n).point;
end

scale = sqrt(width.*height)/sqrt(prod(maxsize));
scale = [scale; scale];
% for multi-example case, scale is 
% 8.20000000000000	8.20000000000000	8.20000000000000	8.20000000000000	8.20000000000000	8.20000000000000	8.20000000000000	8.20000000000000	8.20000000000000
% 8.20000000000000	8.20000000000000	8.20000000000000	8.20000000000000	8.20000000000000	8.20000000000000	8.20000000000000	8.20000000000000	8.20000000000000

% for ssingle example case, scale is  
% 8.20000000000000
% 8.20000000000000

deffeat = cell(1,size(points,1));

for p = 1:size(points,1)    
    %size(points,1) is the size of points in its first dimension
    % for multi-example case, its 1x2x9, size is 1
    % for single-example case, its 1x2, size is 1
    jedPointCheck = points(p,1:2,:);
    
    % for multi-example case, points(p,1:2,:) is
    % val(:,:,1) = 651.1640  278.6615
    % val(:,:,2) = 675.3096  276.8658
    % val(:,:,3) = 664.5088  243.1754
    % ...
    % val(:,:,9) = 668.0608  266.8379

    % for single-example case, its 
    % [441.416000000000,180.031692000000]
    def = squeeze(points(p,1:2,:));
    [dimx, dimy, dimz] = size(def);
    % 2, 9, 1 for multi-example case
    % 1, 2, 1 for single-example case
    if (dimx == 1 && dimy == 2)
        def = def';
    end
    
    
    
    % for multi-example case, def is 
    % 651.164000000000	675.309600000000	664.508800000000	639.873600000000	648.949600000000	630.796800000000	654.136000000000	633.390400000000	668.060800000000
    % 278.661461000000	276.865784000000	243.175387000000	256.133683000000	260.020852000000	272.979148000000	261.316575000000	263.908554000000	266.837922000000

    % for single example case, def is 
    % 441.416000000000	180.031692000000
    deffeat{p} = (def ./ scale)';
    
    % for multip-example case, deffeat {1,1}
    % 79.4102439024390	33.9831050000000
    % 82.3548292682927	33.7641200000000
    % 81.0376585365854	29.6555350000000
    % 78.0333658536586	31.2358150000000
    % 79.1401951219512	31.7098600000000
    % 76.9264390243903	33.2901400000000
    % 79.7726829268293	31.8678750000000
    % 77.2427317073171	32.1839700000000
    % 81.4708292682927	32.5412100000000
    
    % for single example case, breaks
    
    % with transpose fix, looks good
    % [53.8312195121951,21.9550843902439]
end

