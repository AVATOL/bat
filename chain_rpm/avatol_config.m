function [train, test, taxa, meta] = avatol_config(input_folder, params)
%

if exist([params.cachedir 'avatol_config.mat'], 'file')
    fprintf('train, test, taxa, meta are loading from avatol_config.mat.\n');
    load([params.cachedir 'avatol_config.mat']);
    return
end

fprintf('calculating train, test, taxa, meta from scratch.\n');

fsp = filesep;
input_folder = strrep(input_folder, '\', fsp);

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
        meta.chars(end).name = name_shrink(strs{3});
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
        meta.states(end).name = name_shrink(strs{3});
        meta.states(end).cid = strs{4};
        if isempty(strfind(strs{3}, 'present')) % NOTE: only deal with presence
            meta.states(end).presence = 0;
        else
            meta.states(end).presence = 1;
        end
    elseif strcmp(strs{1},'taxon')
        meta.taxa(end+1).id = strs{2};
        meta.taxa(end).name = name_shrink(strs{3});
    elseif strcmp(strs{1},'view')
        meta.views(end+1).id = strs{2};
        meta.views(end).name = name_shrink(strs{3});
    else
        error('summary.txt: unknown line');
    end
end

fclose(fp);

% meta common
meta.taxon_list = {meta.taxa.name};
meta.part_list = {meta.chars.name};
colorset = hsv(length(meta.part_list));
meta.part_color = mat2cell(colorset, ones(1,length(meta.part_list)), 3);
meta.mask_color = meta.part_color(1:2);

% point [x y] part_mask
for n = 1:length(train)
    train(n).point = zeros(length(meta.chars),2); 
    train(n).part_mask = zeros(1,length(meta.chars));
    train(n).nlabels = zeros(length(meta.chars),1); 
    train(n).bb_ratio = 0;
    train(n).sid = cell(length(meta.chars),1);
end

for n = 1:length(test)
    test(n).point = zeros(length(meta.chars),2); 
    test(n).part_mask = zeros(1,length(meta.chars));
    test(n).nlabels = zeros(length(meta.chars),1); 
    test(n).bb_ratio = 0;
    test(n).sid = cell(length(meta.chars),1);
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
            train(tim).sid{i} = sid;
            train(tim).tid = tid;
            train(tim).nlabels(i) = train(tim).nlabels(i) + 1; 

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
            sid = sann{4};
            test(tim).point(i,:) = ratio2coord(sxy, get_abs_path(rt_dir,test(tim).im));
            test(tim).sid{i} = sid;
            test(tim).tid = tid;
            test(tim).nlabels(i) = test(tim).nlabels(i) + 1; 

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
tind = arrayfun(@(x) any(x.nlabels > 2), train);
train(tind) = [];

tind = arrayfun(@(x) any(x.nlabels > 2), test);
test(tind) = [];

%*** black list (incorrect annotations)
blacklist = {'media\M283606.jpg', 'media\M283568.jpg'};
tind = arrayfun(@(x) ismember(x.im, blacklist), train);
train(tind) = [];

% get abs path
for n = 1:length(train)
    train(n).im = get_abs_path(rt_dir,train(n).im);
end

for n = 1:length(test)
    test(n).im = get_abs_path(rt_dir,test(n).im);
end

%% taxa 
[train.setid] = deal(1); [test.setid] = deal(2);
train_test = cat(2,train,test);
is_exclu_taxon = zeros(1,length(meta.taxa));

for i = 1:length(meta.taxa)
    tind = arrayfun(@(x) strcmp(x.tid, meta.taxa(i).id), train_test);
    
    % part_mask (taxon level), deal with inconsistency
    pmasks = cat(1,train_test(tind).part_mask);
    [part_mask,~,rowlocs] = unique(pmasks,'rows');
    tcnt = 0; trow = 1; % find majority mask
    for r = 1:size(part_mask,1)
        [tcnt,ti] = max([tcnt, sum(rowlocs == r)]);
        if ti == 2
            trow = r;
        end
    end
    
    if sum(rowlocs == trow) < 5 % majority must have 5+ samples
        is_exclu_taxon(i) = 1;
        continue
    end
    
    part_mask = logical(part_mask(trow,:));
    taxa(i).num_train_data = sum(rowlocs == trow);
    taxa(i).num_parts = sum(part_mask);
    taxa(i).part_name = meta.part_list(part_mask);
    taxa(i).part_mask = part_mask;
    taxa(i).parent = 0:taxa(i).num_parts-1;
    taxa(i).data_dir = [rt_dir 'media/'];    
    taxa(i).name = meta.taxa(i).name;
    taxa(i).part_color = meta.part_color(taxa(i).part_mask);
    taxa(i).mask_color = meta.mask_color(taxa(i).part_mask+1);
    
    tind = find(tind);
    [train_test(tind(rowlocs == trow)).taxon] = deal(taxa(i).name);
    
    % special bb_ratio
    [tism,tloc] = ismember(taxa(i).name, params.bb_taxa_spec);
    if tism
        [train_test(tind(rowlocs == trow)).bb_ratio] = deal(params.bb_ratio_spec(tloc));
    end
    
    %*** discard samples have diff labels as majority
    % TODO: discarded to test
    train_test(tind(rowlocs ~= trow)) = [];
end

% exclude taxa has inconsistent labels
is_exclu_taxon = logical(is_exclu_taxon);
taxa(is_exclu_taxon) = [];
meta.taxa(is_exclu_taxon) = [];
meta.taxon_list(is_exclu_taxon) = [];

%% bbox
train_test = pointtobox(train_test, params.boxsize, params.bb_ratio, params.bb_cand, params.bb_range);
train = train_test([train_test.setid] == 1);
test = train_test([train_test.setid] == 2);
train = rmfield(train, 'setid');
test = rmfield(test, 'setid');
assert(length(train) + length(test) == length(train_test));
clear train_test

%% save
save([params.cachedir 'avatol_config.mat'], 'train', 'test', 'taxa', 'meta');

%% vis
if (params.show_data == 1)
    for t = 1:length(taxa)
        tind = arrayfun(@(x) strcmp(x.tid, meta.taxa(t).id), train);
        for i = find(tind)
            B = [train(i).x1;train(i).y1;train(i).x2;train(i).y2];
            B = reshape(B,[4*length(train(i).part_mask),1])';
            A = imread(train(i).im);
            showboxes(A,B,taxa(t).mask_color);
            title(sprintf('%s: %d -- %s | bbsz = %d',meta.taxa(t).name, ...
                i,train(i).im(end-10:end),train(i).x2(1) - train(i).x1(1)));
            pause;
        end
    end
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
fsp = filesep;
abspath = strrep(abspath, '\', fsp);


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
point = point .* [w/100 h/100];

function trains = pointtobox(trains, bb_sz, bb_ratio, bb_cand_g, bb_range)
% 

if(nargin < 2)
    bb_sz = 40;
end

for n = 1:length(trains)
    points = trains(n).point;
    bb_cand = bb_cand_g;
    if nargin == 5
        pmsk = trains(n).part_mask;
        tst = find(pmsk(bb_cand), 1, 'first');
        st = bb_cand(tst);
        bb_cand(tst) = [];
        ted = find(pmsk(bb_cand), 1, 'last');
        ed = bb_cand(ted);
        if isempty(st) || isempty(ed)
            boxsize = bb_sz;
        else
            dst_ratio = trains(n).bb_ratio;
            if ~dst_ratio; dst_ratio = bb_ratio(st,ed); end;
            assert(dst_ratio > 0);
            pixel_dst = abs(points(st,1) - points(ed,1));
            boxsize = ceil(pixel_dst / dst_ratio);
            fprintf('%d, boxsize = %d\n', n, boxsize);
        end
    else
        boxsize = bb_sz;
    end
    
    % control size
    boxsize = min(max(boxsize,bb_range(1)),bb_range(2));

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


function name = name_shrink(name)
%

name = strrep(name, 'Upper ', '');
name = strrep(name, ' presence', '');
name = strrep(name, ' ', '-');

