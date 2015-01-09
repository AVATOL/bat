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

deffeat = cell(1,size(points,1));
for p = 1:size(points,1)
    def = squeeze(points(p,1:2,:));
    deffeat{p} = (def ./ scale)';
end

