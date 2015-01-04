function [train test taxa meta] = avatol_config(input_folder, params)
%

% init
[train test] = deal([]);
meta.chars = []; meta.taxa = []; meta.states = []; meta.views = [];
taxa = [];

% root dir
rt_dir = strsplit(input_folder, 'input');
rt_dir = rt_dir{1};

%% read summary.txt -> meta train test
fp = fopen([input_folder '/summary.txt'], 'r');

while 1
    tline = fgetl(fp);
    if ~ischar(tline)
        break
    end

    strs = strsplit(tline, ',');

    if strcmp(strs{1},'character')
        meta.chars(end+1).id = strs{2};
        meta.chars(end).name = strs{3};
    elseif strcmp(strs{1},'media')
        if strcmp(strs{end}, 'training')
            train(end+1).id = strs{2};
            train(end).im = strs{3}; 
        elseif strcmp(strs{end}, 'toScore')
            test(end+1).id = strs{2};
            test(end).im = strs{3};
        else 
            error('unknown media file');
        end
    elseif strcmp(strs{1},'state')
        meta.states(end+1).id = strs{2};
        meta.states(end).name = strs{3};
        meta.states(end).cid = strs{4};
        if isempty(strfind(strs{3}, 'present')) % NOTE: only deal with presence
            meta.states(end).presence = 1;
        else
            meta.states(end).presence = 0;
        end
    elseif strcmp(strs{1},'taxon')
        meta.taxa(end+1).id = strs{2};
        meta.taxa(end).name = strs{3};
    elseif strcmp(strs{1},'view')
        meta.views(end+1).id = strs{2};
        meta.views(end).name = strs{3};
    else
        error('summary.txt: unknown line');
    end
end

fclose(fp);

% meta common
meta.taxon_list = {meta.taxa.name};
meta.part_list = {meta.chars.name};
meta.colorset = hsv(length(meta.chars));

% point [x y] part_mask
for n = 1:length(train)
    train(n).point = zeros(length(meta.chars),2); 
    train(n).part_mask = ones(1,length(meta.chars));
    train(n).nlabels = zeros(length(meta.chars),1); 
end

for n = 1:length(test)
    test(n).point = zeros(length(meta.chars),2); 
    test(n).part_mask = ones(1,length(meta.chars));
    test(n).nlabels = zeros(length(meta.chars),1); 
end

%% read input files -> train test (annotations)
all_files = dir(input_folder);
txt    = arrayfun(@(x) ~isempty(strfind(x.name, 'sorted_')), all_files);
all_files = all_files(logical(txt));
n_parts = numel(all_files);
assert(n_parts == length(meta.chars));

for i = 1:n_parts
    fp = fopen([input_folder '/' all_files(i).name], 'r'); % input file
    
    while 1
        tline = fgetl(fp);
        if ~ischar(tline)
            break
        end
        
        strs = strsplit(tline, '|');

        if strcmp(strs{1},'training_data')
            [im,anno,sid,tid,lid] = parse_train_line(strs);
            tim = arrayfun(@(x) strcmp(x.im, im), train);
            assert(sum(tim) == 1);

            fann = fopen(get_abs_path(rt_dir,anno), 'r'); % anno file

            tann = fgetl(fann); % NOTE: assume only one side: use line 1 not 2 in input file
            sann = strsplit(tann, ':');
            sxy = strsplit(sann{1}, ',');
            train(tim).point(i,:) = ratio2coord(sxy, get_abs_path(rt_dir,train(tim).im));
            train(tim).sid = sid;
            train(tim).tid = tid;
            train(tim).nlabels(i) = train(tim).nlabels(i) + 1; 
            train(tim).im = get_abs_path(rt_dir,train(tim).im);

            tst = arrayfun(@(x) strcmp(x.id, sid), meta.states);
            assert(strcmp(meta.states(tst).cid, meta.chars(i).id));
            train(tim).part_mask(i) = meta.states(tst).presence;
                
            fclose(fann);
        elseif strcmp(strs{1},'image_to_score')
            [im,anno,tid,lid] = parse_test_line(strs);
            tim = arrayfun(@(x) strcmp(x.im, im), test);
            assert(sum(tim) == 1);

            fann = fopen(get_abs_path(rt_dir,anno), 'r'); % anno file

            tann = fgetl(fann); % NOTE: assume only one side: use line 1 not 2 in input file
            sann = strsplit(tann, ':');
            sxy = strsplit(sann{1}, ',');
            test(tim).point(i,:) = ratio2coord(sxy, get_abs_path(rt_dir,test(tim).im));
            test(tim).tid = tid;
            test(tim).nlabels(i) = test(tim).nlabels(i) + 1; 
            test(tim).im = get_abs_path(rt_dir,test(tim).im);

            tst = arrayfun(@(x) strcmp(x.id, sid), meta.states);
            assert(strcmp(meta.states(tst).cid, meta.chars(i).id));
            test(tim).part_mask(i) = meta.states(tst).presence;
                
            fclose(fann);
        else
            error('Neither train or test image');
        end
    end
    
    fclose(fp);
end

% remove duplicated samples
tind = arrayfun(@(x) any(x.visit > 2), train);
train(tind) = [];

tind = arrayfun(@(x) any(x.visit > 2), test);
test(tind) = [];

%% taxa 
for i = 1:length(meta.taxa)
    tind = arrayfun(@(x) strcmp(x.tid, meta.taxa(i).id, train);
    pmasks = cat(1,train(tind).part_mask);
    part_mask = logical(unique(pmasks,'rows'));
    assert(size(part_mask,1) == 1);

    taxa(i).num_train_data = sum(tind);
    taxa(i).num_parts = sum(part_mask);
    taxa(i).part_name = meta.part_list(part_mask);
    taxa(i).part_mask = part_mask;

    % common
    taxa(i).parent = 0:taxa(i).num_parts-1;
    taxa(i).data_dir = [rt_dir 'media/'];    
    taxa(i).name = meta.taxa(i).name;
    taxa(i).part_color = mat2cell(meta.colorset, ...
        ones(1,length(meta.chars)), 3); % TODO: part_mask it?
    taxa(i).bb_const = [0.8 1.5];
end


%% helper functions
function [media,anno,sid,tid,labelid] = parse_train_line(str)
assert(strcmp(str{1},'training_data'));
media = str{2};
anno = str{5};
sid = str{3};
tid = str{6};
labelid = str{7};

function [media,anno,tid,labelid] = parse_test_line(str)
assert(strcmp(str{1},'image_to_score'));
media = str{2};
anno = str{4};
tid = str{3};
labelid = str{5};


function abspath = get_abs_path(rt_dir, path)
abspath = [rt_dir path];
abspath = strrep(abspath, '\', '/');


function point = ratio2coord(sxy, absim, is_resiz)
if nargin < 3
    is_resiz = 0;
end

default_x = 780;
default_y = 520;

point = [str2double(sxy{1}),str2double(sxy{2})]; % (x,y)
im = imread(absim);
if is_resiz; im = imresize(im, [default_y default_x]); end;
[h,w,~] = size(im);
point = point .* [w h];
