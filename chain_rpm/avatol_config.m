function [train, test, taxa, meta, train_pruned, test_pruned] = avatol_config(input_folder, params)
%

if exist([params.cachedir 'avatol_config.mat'], 'file')
    fprintf('train, test, taxa, meta are loading from avatol_config.mat.\n');
    load([params.cachedir 'avatol_config.mat']);
    return
end

fprintf('calculating train, test, taxa, meta from scratch.\n');

fsp = filesep;
input_folder = strrep(input_folder, '\', fsp);

% init the empty arrays
[train test] = deal([]);
meta.chars = []; meta.taxa = []; meta.states = []; meta.views = [];
taxa = [];

% root dir (JED - winds up being the legacy format dir that Michael populated)
rt_dir = strsplit(input_folder, 'input');
rt_dir = rt_dir{1};

%% read summary.txt -> meta train test  (JED legacy_format\input/summary.txt)
filename = [input_folder '/summary.txt'];
if ~exist(filename, 'file')
    error('file does not exist: %s', filename);
end
fp = fopen(filename, 'r');

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
            train(end+1).id = strs{2}; %403279__1000
            train(end).im = strs{3}; % C:\jed\avatol\git\avatol_cv\sessions\Bat Skull Matrix\normalized\images\large\403279__1000.jpg
            train(end).pruned = 0; % 0
        elseif strcmp(strs{end}, 'toScore')
            test(end+1).id = strs{2}; % these three are same format at train[] entries
            test(end).im = strs{3};
            test(end).pruned = 0;
        else 
            error('unknown media file');
        end
    elseif strcmp(strs{1},'state')
        meta.states(end+1).id = strs{2};  %4942237 - likely state id
        meta.states(end).name = name_shrink(strs{3}); % well-developed-postorbital-process-present
        meta.states(end).cid = strs{4}; %1847859 - likely character id
        if isempty(strfind(strs{3}, 'present')) % NOTE: only deal with presence
            meta.states(end).presence = 0;
        else
            meta.states(end).presence = 1;
        end
    elseif strcmp(strs{1},'taxon')
        meta.taxa(end+1).id = strs{2};
        meta.taxa(end).name = name_shrink(strs{3});
        if strcmp(strs{4},'training')
            meta.taxa(end).split = 1;  %it's a training sample
        elseif strcmp(strs{4},'scoring')
            meta.taxa(end).split = 0; %it's a scoring sample
        else
            error('unknown train-test split');
        end
    elseif strcmp(strs{1},'view')
        meta.views(end+1).id = strs{2};
        meta.views(end).name = name_shrink(strs{3});
    elseif strcmp(strs{1},'inputDir')
        continue
    elseif strcmp(strs{1},'outputDir')
        continue
    elseif strcmp(strs{1},'detectionResultsDir')
        continue
    else
        error('summary.txt: unknown line');
    end
end

fclose(fp);

% meta common
meta.taxon_list = {meta.taxa.name}; % JED list of just the names
meta.part_list = {meta.chars.name}; % JED list of just the characters
colorset = hsv(length(meta.part_list));
if length(meta.part_list) == 1  %jedfix
    meta.part_color = mat2cell([[1,0,0];[0,1,1]],ones(1,2),3); %jedfix
else   %jedfix
    meta.part_color = mat2cell(colorset, ones(1,length(meta.part_list)), 3);
    % this was the case for 2 chars
    % [1,0,0]
    % [0,1,1]
end  %jedfix
meta.mask_color = meta.part_color(1:2);

% next sections make zero-initialized data structure to hold everything
% point [x y] part_mask
for n = 1:length(train)
    train(n).point = zeros(length(meta.chars),2); 
    train(n).part_mask = zeros(1,length(meta.chars));
    train(n).nlabels = zeros(length(meta.chars),1); 
    train(n).bb_ratio = 0;
    train(n).sid = cell(length(meta.chars),1);  %one for each character in play
    train(n).tid = -1; % will be overwritten
end

for n = 1:length(test)
    test(n).point = zeros(length(meta.chars),2); 
    test(n).part_mask = zeros(1,length(meta.chars));
    test(n).nlabels = zeros(length(meta.chars),1); 
    test(n).bb_ratio = 0;
    test(n).sid = cell(length(meta.chars),1);%one for each character in play
    test(n).tid = -1; % will be overwritten
end

%% read input files -> train test (annotations)
all_files = dir(input_folder);
txt    = arrayfun(@(x) ~isempty(strfind(x.name, 'sorted_')), all_files);
all_files = all_files(logical(txt));
n_parts = numel(all_files);
assert(n_parts == length(meta.chars));

for i = 1:n_parts
    filename = [input_folder '/' all_files(i).name];
    if ~exist(filename, 'file')
        error('file does not exist: %s', filename);
    end
    fp = fopen(filename, 'r'); % input file
    
    while 1
        tline = fgetl(fp);
        if ~ischar(tline)
            break
        end
%         if ~isempty(strfind(tline, 'NA'))
%             continue
%         end
        
        strs = strsplit(tline, '|');

        if strcmp(strs{1},'training_data')
            [im,anno,sid,tid,lid] = parse_train_line(strs); %JED: image, annotation, taxonID, line number in annotations file
            tim = arrayfun(@(x) strcmp(x.im, im), train); %JED: a logical mask selecting training entry matching the image
            assert(sum(tim) == 1);

            filename = get_abs_path(rt_dir,anno);
            if ~exist(filename, 'file')
                error('file does not exist: %s', filename);
            end
            fann = fopen(filename, 'r'); % anno file
%             fann = fopen(anno, 'r'); % anno file

            tann = fgetl(fann); % NOTE: assume only one side: use line 1 not 2 in input file
            sann = strsplit(tann, ':');
            sxy = strsplit(sann{1}, ','); %JED: isolating the x and y coords from the input line
            train(tim).point(i,:) = ratio2coord(sxy, get_abs_path(rt_dir,train(tim).im));
%             train(tim).point(i,:) = ratio2coord(sxy, train(tim).im);
            train(tim).sid{i} = sid; 
            train(tim).tid = tid;
            train(tim).nlabels(i) = train(tim).nlabels(i) + 1; 

            %JED: tst is t_state, a mask which selects from the matrix of character states based on charStateID matc
            tst = arrayfun(@(x) strcmp(x.id, sid), meta.states);  
            % JED: make sure the characater IDs match, which we'd expe ct for matching charStateID
            assert(strcmp(meta.states(tst).cid, meta.chars(i).id));
            % JED: accumulate part/presence absence indication for each training image, 
            % JED:  so, part_mask could be [1,0] if the first character is present and the second is not, or [1,1] if both are there
            train(tim).part_mask(i) = meta.states(tst).presence;
                
            fclose(fann);
        elseif strcmp(strs{1},'image_to_score')
            [im,anno,tid,lid] = parse_test_line(strs);
            tim = arrayfun(@(x) strcmp(x.im, im), test);
            assert(sum(tim) == 1);

%             filename = get_abs_path(rt_dir,anno);
%             if ~exist(filename, 'file')
%                 error('file does not exist: %s', filename);
%             end
%             fann = fopen(filename, 'r'); % anno file
%             fann = fopen(anno, 'r'); % anno file
% 
%             tann = fgetl(fann); % NOTE: assume only one side: use line 1 not 2 in input file
%             sann = strsplit(tann, ':');
%             sxy = strsplit(sann{1}, ',');
%             sid = sann{4};
%             test(tim).point(i,:) = ratio2coord(sxy, get_abs_path(rt_dir,test(tim).im));
%             test(tim).point(i,:) = ratio2coord(sxy, test(tim).im);
%             test(tim).sid{i} = sid;
            test(tim).tid = tid;
            test(tim).nlabels(i) = test(tim).nlabels(i) + 1; 

            tst = arrayfun(@(x) strcmp(x.id, sid), meta.states);
            assert(strcmp(meta.states(tst).cid, meta.chars(i).id));
            test(tim).part_mask(i) = meta.states(tst).presence;
                
%             fclose(fann);
        else
            error('Neither train or test image');
        end
    end
    
    fclose(fp);
end

% remove duplicated samples
tind = arrayfun(@(x) any(x.nlabels > 2), train);
[train(tind).pruned] = deal(1);

tind = arrayfun(@(x) any(x.nlabels > 2), test);
[test(tind).pruned] = deal(1);

%*** black list (incorrect annotations)
% JED - this likely no longer valid blacklist
% blacklist = {'media\M283606.jpg', 'media\M283568.jpg'};
% tind = arrayfun(@(x) ismember(x.im, blacklist), train);
% [train(tind).pruned] = deal(1);

% get abs path
for n = 1:length(train)
    train(n).im = get_abs_path(rt_dir,train(n).im);
%     train(n).im = train(n).im;
end

for n = 1:length(test)
    test(n).im = get_abs_path(rt_dir,test(n).im);
%     test(n).im = test(n).im;
end

%% taxa 
[train.setid] = deal(1); [test.setid] = deal(2);
train_test = cat(2,train,test);  % make one combined matrix
is_exclu_taxon = zeros(1,length(meta.taxa)); % setup mask for exclusion

for i = 1:length(meta.taxa)
    % JED:tind (tason indices) will be a mask that will select all the entries in train_test that have the same taxon id as the i'th taxon in meta.taxa.
    tind = arrayfun(@(x) strcmp(x.tid, meta.taxa(i).id), train_test);  
    
    % part_mask (taxon level), deal with inconsistency
    % JED: collect all the part masks that are associated with all the entries of chosen taxon
    % part_mask for a training example will be, for two character case either [0,0] (neither char present), [1,0] (first char present, second not), etc
    pmasks = cat(1,train_test(tind).part_mask);
    [part_mask,~,rowlocs] = unique(pmasks,'rows');
    tcnt = 0; trow = 1; % find majority mask
    % JED: if different images for this taxon have conflicting claims about which parts are present or absent, just find mask
    %...that's present the most.
    for r = 1:size(part_mask,1)
        [tcnt,ti] = max([tcnt, sum(rowlocs == r)]);
        if ti == 2
            trow = r;
        end
    end
    % Exclude any taxon that has no mask in play for some reason
%     if sum(rowlocs == trow) < 5 % majority must have 5+ samples
    if sum(rowlocs == trow) < 1 % majority must have 1+ samples
        is_exclu_taxon(i) = 1;
        continue
    end
    
    % JED : the winning part_mask
    part_mask = logical(part_mask(trow,:));
    % JED : the number of training samples for this taxa with that winning part_mask
    taxa(i).num_train_data = sum(rowlocs == trow);
    % JED : number of parts deemed present
    taxa(i).num_parts = sum(part_mask);
    taxa(i).part_name = meta.part_list(part_mask);
    taxa(i).part_mask = part_mask;
    taxa(i).parent = 0:taxa(i).num_parts-1; %JED: ???
    taxa(i).data_dir = [rt_dir 'media/'];    
    taxa(i).name = meta.taxa(i).name;
    taxa(i).part_color = meta.part_color(taxa(i).part_mask);
    taxa(i).mask_color = meta.mask_color(taxa(i).part_mask+1);
    % JED split is 1 for train , 0 for score
    taxa(i).split = meta.taxa(i).split;
    
    tind = find(tind);
%     [train_test(tind(rowlocs == trow)).taxon] = deal(taxa(i).name);
    % JED : assign the taxon name to the taxon row in train_test
    [train_test(tind).taxon] = deal(taxa(i).name);
    
    % special bb_ratio
% JED - don't want this special treatment for certain taxa
%   [tism,tloc] = ismember(taxa(i).name, params.bb_taxa_spec);
%    if tism
%        [train_test(tind(rowlocs == trow)).bb_ratio] = deal(params.bb_ratio_spec(tloc));
%    end
    
    %*** discard samples have diff labels as majority
    % TODO: discarded to test
    [train_test(tind(rowlocs ~= trow)).pruned] = deal(1);
end

% exclude taxa has inconsistent labels
is_exclu_taxon = logical(is_exclu_taxon);
% taxa(is_exclu_taxon) = [];
meta.taxa(is_exclu_taxon) = [];
meta.taxon_list(is_exclu_taxon) = [];

%% bbox
%train_test = pointtobox(train_test, params.boxsize, params.bb_ratio, params.bb_cand, params.bb_range);
train_test = pointtoboxSimple(train_test, params.bb_range); %JED bypass some bugs related to 5 character assumption
train = train_test([train_test.setid] == 1);
test = train_test([train_test.setid] == 2);
train = rmfield(train, 'setid');
test = rmfield(test, 'setid');
assert(length(train) + length(test) == length(train_test));
clear train_test

%% separate into train/test sets and pruned images
tind = arrayfun(@(x) any(x.pruned == 1), train);
train_pruned = train(tind);
train_pruned = rmfield(train_pruned, 'pruned');

tind = arrayfun(@(x) any(x.pruned == 1), test);
test_pruned = test(tind);
test_pruned = rmfield(test_pruned, 'pruned');

tind = arrayfun(@(x) any(x.pruned == 0), train);
train = train(tind);
train = rmfield(train, 'pruned');

tind = arrayfun(@(x) any(x.pruned == 0), test);
test = test(tind);
test = rmfield(test, 'pruned');

%% save
save([params.cachedir 'avatol_config.mat'], 'train', 'test', 'taxa', 'meta', 'train_pruned', 'test_pruned');

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
% abspath = [rt_dir path];
% fsp = filesep;
% abspath = strrep(abspath, '\', fsp);
abspath = path;


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



function trains = pointtoboxSimple(trains, bb_range)
% 

    bb_sz = 40;

for n = 1:length(trains)
    points = trains(n).point;
    boxsize = bb_sz;
    
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
        pmsk(bb_cand)
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

