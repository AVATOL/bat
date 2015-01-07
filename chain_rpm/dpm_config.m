function [train test taxa meta] = dpm_config(rt_dir, params)

if exist([params.cachedir 'dpm_config.mat'], 'file')
    fprintf('train, test, taxa, meta are loading from dpm_config.mat.\n');
    load([params.cachedir 'dpm_config.mat']);
    return
end

fprintf('calculating train, test, taxa, meta from scratch.\n');

[taxa meta] = taxon_config(rt_dir);
[train, test] = data_sets(taxa, params);

save([params.cachedir 'dpm_config.mat'], 'train', 'test', 'taxa', 'meta');


function [taxa,meta] = taxon_config(rt_dir)
% include 8 taxa

if nargin < 1
    rt_dir = '../data/vent_small/';
end

meta.taxon_list = {'Artibeus','Noctilio','Trachops','Molossus',...
    'Mormoops','Saccopteryx','Glossophaga','Desmodus'};
meta.part_list = {'I1','C','P4','P5','M1','M2'};
colorset = hsv(length(meta.part_list));
meta.part_color = mat2cell(colorset, ones(1,length(meta.part_list)), 3);
meta.mask_color = meta.part_color(1:2);

taxa(length(meta.taxon_list)).num_parts = 6;

for i = 1:length(meta.taxon_list)
    % common
    taxa(i).rt_dir = rt_dir;
    taxa(i).num_train_data = 8;
    taxa(i).name = meta.taxon_list{i};

    if strcmp(meta.taxon_list{i},'Artibeus')
        taxa(i).num_parts = 6;
        taxa(i).bb_const = [0.8 1.5];
        taxa(i).part_name = {'I1','C','P4','P5','M1','M2'};
        taxa(i).part_mask = logical([1 1 1 1 1 1]);
        taxa(i).prefix = 'A';
    elseif strcmp(meta.taxon_list{i},'Noctilio')
        taxa(i).num_parts = 5;
        taxa(i).bb_const = [0.8 1.5];
        taxa(i).part_name = {'I1','C','P5','M1','M2'};
        taxa(i).part_mask = logical([1 1 0 1 1 1]);
        taxa(i).prefix = 'N';
    elseif strcmp(meta.taxon_list{i},'Trachops')
        taxa(i).num_parts = 6;
        taxa(i).bb_const = [0.8 1.5];
        taxa(i).part_name = {'I1','C','P4','P5','M1','M2'};
        taxa(i).part_mask = logical([1 1 1 1 1 1]);
        taxa(i).prefix = 'T';
    elseif strcmp(meta.taxon_list{i},'Molossus')
        taxa(i).num_parts = 5;
        taxa(i).bb_const = [0.8 1.5];
        taxa(i).part_name = {'I1','C','P5','M1','M2'};
        taxa(i).part_mask = logical([1 1 0 1 1 1]);
        taxa(i).prefix = 'M1';
    elseif strcmp(meta.taxon_list{i},'Mormoops')
        taxa(i).num_parts = 6;
        taxa(i).bb_const = [0.8 1.5];
        taxa(i).part_name = {'I1','C','P4','P5','M1','M2'};
        taxa(i).part_mask = logical([1 1 1 1 1 1]);
        taxa(i).prefix = 'M2';
    elseif strcmp(meta.taxon_list{i},'Saccopteryx')
        taxa(i).num_parts = 5;
        taxa(i).bb_const = [0.8 1.5];
        taxa(i).part_name = {'C','P4','P5','M1','M2'};
        taxa(i).part_mask = logical([0 1 1 1 1 1]);
        taxa(i).prefix = 'S';
    elseif strcmp(meta.taxon_list{i},'Glossophaga')
        taxa(i).num_parts = 6;
        taxa(i).bb_const = [0.8 1.2];
        taxa(i).part_name = {'I1','C','P4','P5','M1','M2'};
        taxa(i).part_mask = logical([1 1 1 1 1 1]);
        taxa(i).prefix = 'G';
    elseif strcmp(meta.taxon_list{i},'Desmodus')
        taxa(i).num_parts = 4;
        taxa(i).bb_const = [0.8 1.0];
        taxa(i).part_name = {'N','I1','C','P5','M1','I1','C','P5','M1'};
        taxa(i).part_mask = logical([1 1 0 1 1 0]);
        taxa(i).prefix = 'D';
    end

    % common
    %taxa(i).part_name = intersect(taxa(i).part_name, meta.part_list);
    taxa(i).data_dir = [taxa(i).rt_dir, taxa(i).prefix, '/'];
    taxa(i).parent = 0:taxa(i).num_parts-1;
    
    %taxa(i).part_color = mat2cell(meta.colorset(taxa(i).part_mask,:), ...
    %    ones(1,taxa(i).num_parts), 3);
    taxa(i).part_color = meta.part_color(taxa(i).part_mask);
    taxa(i).mask_color = meta.mask_color(taxa(i).part_mask+1);
end


function [trainset, testset] = data_sets(taxa, params)
%

[trainset, testset] = deal([]);

for taxon = taxa
    % png files
    all_files = dir(taxon.data_dir);
    png    = arrayfun(@(x) ~isempty(strfind(x.name, 'png')), all_files);
    all_files = all_files(logical(png));

    % split train test
    perm = randperm(numel(all_files)); % random
    % perm = 1:numel(all_files); % seq
    train_index = perm(1:taxon.num_train_data);
    test_index = perm(taxon.num_train_data+1:end);
    train_files = all_files(train_index);
    test_files = all_files(test_index);
    
    % annotation
    annotateParts(taxon.data_dir, 'png', '', taxon.part_name, train_files);
    
    % prepare data sets
    [trains, tests] = prepare_sets(taxon.name, taxon.data_dir, taxon.part_mask, ...
        train_files, test_files);
    trains = temp_process_points(trains, taxon); % TODO: redo anno 
    
    % convert annotated points to bounding boxes
    %trains = pointtobox(trains,taxon.parent,taxon.bb_const1,taxon.bb_const2);
    trains = pointtobox(trains,params.boxsize);

    % add to global trainset testset
    trainset = cat(2, trainset, trains);
    testset = cat(2, testset, tests);
    
    % visualize training data
    if (params.show_data == 1)
        % show data
        for i=1:length(trains)
            B = [trains(i).x1;trains(i).y1;trains(i).x2;trains(i).y2];
            B = reshape(B,[4*length(taxon.part_mask),1])';
            A = imread(trains(i).im);
            showboxes(A,B,taxon.part_color);
            pause;
        end
    end
end 


%% helper functions
function [train test] = prepare_sets(tname, directory, pmsk, train_files, test_files)
% 

[train test] = deal([]);

% remove trailing slash from the directory if need be
if isequal(directory(end), '/') directory = directory(1:end-1); end

% import the examples into the structure
for n = 1:numel(train_files)
    train(n).im     = [directory '/' train_files(n).name];
    [lead name ext] = fileparts(train_files(n).name);
    train(n).point  = dlmread([directory '/' name 'parts.txt']);
    train(n).taxon  = tname;
    train(n).part_mask  = pmsk;
end

for n = 1:numel(test_files)
    test(n).im      = [directory '/' test_files(n).name];
    test(n).taxon   = tname;
    test(n).part_mask  = pmsk;
end

function train = temp_process_points(train, taxon)
% NOTE: a temporal function for current annotations

for n = 1:numel(train)
    points = train(n).point;
    num = size(points,1);
    assert((num-1)/2 == sum(taxon.part_mask));
    points = points(2:(num-1)/2+1,:);
    train(n).point = zeros(length(taxon.part_mask),2);
    train(n).point(taxon.part_mask,:) = points;
end

function trains = pointtobox(trains,boxsize)
% 

if(nargin < 2)
    boxsize = 40;
end

for n = 1:length(trains)
    points = trains(n).point;
    for p = 1:size(points,1)
        if isequal(points(p,:), [0,0])
            continue
        end
        trains(n).x1(p) = points(p,1) - boxsize/2;
        trains(n).y1(p) = points(p,2) - boxsize/2;
        trains(n).x2(p) = points(p,1) + boxsize/2;
        trains(n).y2(p) = points(p,2) + boxsize/2;
    end
end
