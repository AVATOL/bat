function model = add_factors(model, trains, params)
% TODO: support adding with DAG

num_parts = model.num_parts;
parent = model.parent;

df = data_def(trains, params.maxsize);

for k = 1:num_parts
    model = add_node(model, params.tsize, k);

    par = parent(k);
    if par
        model = add_edge(model, df, k, par);
    end
end


%% helper functions
function model = add_node(model, tsize, k)

model.bias(k).w = 0;
model.bias(k).i = model.len + 1;
model.len = model.len + 1;

model.node(k).w = zeros(tsize);
model.node(k).i = model.len + 1;
model.len = model.len + prod(tsize);

function model = add_edge(model, df, k, par)

model.edge(k).w = [0.01 0 0.01 0];
model.edge(k).i = model.len + 1;
x = mean(df{k}(:,1) - df{par}(:,1));
y = mean(df{k}(:,2) - df{par}(:,2));
model.edge(k).anchor = round([x+1 y+1 0]);
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

