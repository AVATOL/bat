function [train test config] = avatol_config(list_chars, input_folder)

full_parts = {'I1','I2','C','P1','P4','P5','M1','M2','M3'};
part_mask = ones(1,length(full_parts));

all_files = dir(input_folder);
txt    = arrayfun(@(x) ~isempty(strfind(x.name, 'sorted_')), all_files);
all_files = all_files(logical(txt));
n_parts = numel(all_files);

% get all images
rt_dir = strsplit(input_folder, 'input');
rt_dir = rt_dir{1};
[train test] = deal([]);
%fp = fopen([input_folder '/image_list.txt'], 'r');
fp = fopen([input_folder '/' all_files(1).name], 'r');
k = 1;
r = 1;
while 1
    tline = fgetl(fp);
    if ~ischar(tline)
        break
    end
    strs = strsplit(tline, '|');
    %assert(length(strs) == 2);
    if strcmp(strs{1},'training_data')
        if strcmp(strs{end}, '1')
            continue
        end
        train(k).im = strs{2};
        train(k).left_parts = -1.*ones(length(full_parts), 2);
        train(k).right_parts = -1.*ones(length(full_parts), 2);
        k = k + 1;
    elseif strcmp(strs{1},'image_to_score')
        test(r).im = [rt_dir strs{2}];
        r = r + 1;
    else
        error('Neither train image or test image!');
    end
end
fclose(fp);

% get annotations
for i = 1:length(full_parts)
    tpart = arrayfun(@(x) ~isempty(strfind(x.name, full_parts{i})), all_files);
    if all(tpart == 0)
        part_mask(i) = 0;
        continue
    end
    assert(sum(tpart) == 1);
    fp = fopen([input_folder '/' all_files(tpart).name], 'r');
    
    while 1
        tline = fgetl(fp);
        if ~ischar(tline)
            break
        end
        
        % each line
        % TODO: make use of line number in anno files
        strs = strsplit(tline, '|');
        if strcmp(strs{1},'training_data')
            [im,anno] = get_im_anno(strs);
            tim = arrayfun(@(x) strcmp(x.im, im), train);
            assert(sum(tim) == 1);
            fann = fopen([rt_dir anno], 'r');
            
            % left
            tann = fgetl(fann);
            sann = strsplit(tann, ':');
            sxy = strsplit(sann{1}, ',');
            train(tim).left_parts(i,1) = str2double(sxy{1});
            train(tim).left_parts(i,2) = str2double(sxy{2});
            
            % right
            tann = fgetl(fann);
            sann = strsplit(tann, ':');
            sxy = strsplit(sann{1}, ',');
            train(tim).right_parts(i,1) = str2double(sxy{1});
            train(tim).right_parts(i,2) = str2double(sxy{2});
                
            fclose(fann);
        elseif strcmp(strs{1},'image_to_score')
            
        else
            error('Neither train image or test image!');
        end
    end
    
    fclose(fp);
end

for i = 1:length(train)
    train(i).point = zeros(n_parts*2+1, 2);
    left_parts = train(i).left_parts(train(i).left_parts(:,1)>=0,:);
    right_parts = train(i).right_parts(train(i).right_parts(:,1)>=0,:);
    train(i).point(1,:) = (left_parts(3,:) + right_parts(3,:))./2;
    train(i).point(2:n_parts+1,:) = left_parts;
    train(i).point(2+n_parts:end,:) = right_parts;
    
    train(i).im = [rt_dir train(i).im];
end

config = {};
config.num_train_data = length(train);
config.num_parts = n_parts*2+1;
config.bb_const1 = 0.8;
config.bb_const2 = 1.5;
config.prefix = list_chars;
config.name = [list_chars, '_', num2str(config.num_parts), '_', num2str(config.num_train_data)];
config.num_mix = ones(1,config.num_parts);
config.part_mask = logical([1 part_mask part_mask]);
config.parent = 0:config.num_parts-1;
config.parent(n_parts+2) = 1;

config.part_color = cell(1,config.num_parts);
colorset = hsv((length(config.part_mask)-1) / 2 + 1);
colorset = [colorset; colorset(2:end,:)];
colorset = colorset(config.part_mask,:);
config.part_color = mat2cell(colorset, ones(1,config.num_parts), 3);
config.full_parts = full_parts;


function [media,anno] = get_im_anno(str)
%str = strsplit(tline, '|');
assert(strcmp(str{1},'training_data'));
media = str{2};
anno = str{5};
