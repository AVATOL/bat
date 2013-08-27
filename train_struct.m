function model_scores = train_struct(rt_path, nInstances, target, sources, ...
    show_data, demo_active, save_model)
% train_struct.m
% nInstances = 20; % # of images
% class_name = {'A', 'G', 'M1', 'M2', 'N', 'S', 'T'};
% target = 'M1';
% sources = setdiff(class_name, target);
% rt_path = '/home/hushell/working/AVATOL/datasets/Bat/vent_exp_transfer_resized/';

all_name = {'A', 'G', 'M1', 'M2', 'N', 'S', 'T'};

if nargin < 4
    sources = setdiff(all_name, target);
    show_data = 0;
    demo_active = 0;
    save_model = 1;
end

if nargin < 5
    show_data = 0;
    demo_active = 0;
    save_model = 1;
end

tdir = [rt_path target '/'];

%% step 1: go to SIFTflow to get {target_from_sources{i}}

%% step 2: train sources and transfer, i.e. training_NClass_cross_val.m and training_SClass_cross_val.m
% in this step, outputs will be part locations and store in Molossus_from_N
% and Molossus_from_S respectively, e.g. 263275-resize-parts.txt
% NOTE: step 2 has been merged to step 3

num_sources = length(sources);

%% step 3: train models target_from_sources

K = cell(1, num_sources);
pa = cell(1, num_sources);
name = cell(1, num_sources);
colorset = cell(1, num_sources);
dir_txt = cell(1, num_sources);

% 1) training source, 2) testing on warped images, 3) train transferred
s = [0.8 1; % A
    0.8 1;  % G
    0.8 1;  % M1
    0.8 1;  % M2
    0.8 1.5;% N
    0.8 1;  % S
    0.8 1;  % T
    ];
for ai = 1:length(all_name)
    cls_name = all_name{ai};
    [isIn, loc] = ismember(cls_name, sources);
    if isIn
        if strcmp(cls_name, 'N')
            % pname = {'N', 'I1', 'I2', 'C', 'P5', 'M1', 'M2', 'I1', 'I2', 'C', 'P5', 'M1', 'M2'};
            K_t = [1 1 1 1 1 1 1 1 1 1 1 1 1];
            pa_t = [0 1 2 3 4 5 6 1 8 9 10 11 12];
        elseif strcmp(cls_name, 'S')
            % pname = {'N', 'I2', 'C', 'P4', 'P5', 'M1', 'M2', 'I2', 'C', 'P4', 'P5', 'M1', 'M2'};
            K_t = [1 1 1 1 1 1 1 1 1 1 1 1 1];
            pa_t = [0 1 2 3 4 5 6 1 8 9 10 11 12];
        elseif strcmp(cls_name, 'M1')
            % pname = {'N', 'I1', 'C', 'P5', 'M1', 'M2', 'I1', 'C', 'P5', 'M1', 'M2'};
            K_t = [1 1 1 1 1 1 1 1 1 1 1];
            pa_t = [0 1 2 3 4 5 1 7 8 9 10];
        else % (A, G, M2, T)
            % pname = {'N', 'I1', 'I2', 'C', 'P4', 'P5', 'M1', 'M2', 'I1', 'I2', 'C', 'P4', 'P5', 'M1', 'M2'};
            K_t = [1 1 1 1 1 1 1 1 1 1 1 1 1 1 1];
            pa_t = [0 1 2 3 4 5 6 7 1 9 10 11 12 13 14];
        end
        name_t = [target '_from_' cls_name];
        num_parts = length(pa_t);
        part_color = hsv((num_parts-1) / 2 + 1);
        part_color = [part_color; part_color(2:end,:)];
        colorset_t = cell(1,num_parts);
        for i = 1:num_parts
            colorset_t{i} = part_color(i,:);
        end
        dir_txt_t = [rt_path name_t];

        s1 = s(ai,1);
        s2 = s(ai,2);
        dir_cls = [rt_path cls_name '/'];
        % 1)
        train_model_from_prior(dir_cls, K_t, pa_t, cls_name, colorset_t, ...
            [dir_cls '/pos/'], s1, s2, show_data, demo_active, save_model);
        
        % 2)
        load([cls_name '_eval.mat'])
        test_on_warped(allModels{1}, dir_txt_t, tdir, num_parts, colorset_t, 1);
        
        % 3)
        train_model_from_prior(tdir, K_t, pa_t, name_t, colorset_t, dir_txt_t, ...
            s1, s2, show_data, demo_active, save_model);

        % record params
        K{loc} = K_t;
        pa{loc} = pa_t;
        name{loc} = name_t;
        colorset{loc} = colorset_t;
        dir_txt{loc} = dir_txt_t;
    else
        % TODO: normal fully supervised training
    end
end

%% step 4: fuse models
% Strategies
% i) apply each transferred source model separately, get max for each part.
% ii) TODO: get average part responce maps, do inference on average maps.
% iii) TODO: use mean locations of each part
% iv) TODO: init as iii), estimate densities based on these response maps,
%     new detections use AAM like filtering, i.e. solve a quadratic opt
% v) TODO: init with any above strategy, but use expected loss

% g_p = {'N, 'I1_u', 'I2_u', 'C_u', 'P4_u', 'P5_u', 'M1_u', 'M2_u', ...
%     'I1_l', 'I2_l', 'C_l', 'P4_l', 'P5_l', 'M1_l', 'M2_l'};
g_part_scores = ones(nInstances, 15) .* -Inf;
g_part_points = zeros(nInstances, 15, 2);
g_part_model_indicator = ones(nInstances, 15);

for mi = 1:num_sources
    if strcmp(sources{mi}, 'N') == 1
        part_bool = logical([1 1 1 1 0 1 1 1 1 1 1 0 1 1 1]);
    elseif strcmp(sources{mi}, 'S') == 1
        part_bool = logical([1 0 1 1 1 1 1 1 0 1 1 1 1 1 1]);
    elseif strcmp(sources{mi}, 'M1') == 1
        part_bool = logical([1 1 0 1 0 1 1 1 1 0 1 0 1 1 1]);
    else
        part_bool = logical([1 1 1 1 1 1 1 1 1 1 1 1 1 1 1]);
    end
    
    load([name{mi} '_eval.mat'])
    
    numparts = sum(part_bool);
     
    TT1 = cat(2,allTests{:});
    TT1 = TT1(:);
    TT1 = TT1';
    model = allModels{1};
    
    suffix = num2str(K{mi}')';
    model.thresh = min(model.thresh,-2);
    [boxes, pscores] = testmodel(name{mi},model,TT1,suffix);
    
    for ii = 1:nInstances
        new_pscores = pscores{ii}(1,:);
        old_pscores = g_part_scores(ii, part_bool);
        [t_ps, t_mi] = max([old_pscores; new_pscores], [], 1);
        
        m_ind = g_part_model_indicator(ii, part_bool);
        m_ind(t_mi == 2) = mi;
        
        b_pn = g_part_points(ii, part_bool, :);
        box = boxes{ii}(1,:);
        box = box(:,1:4*numparts);
        xy = reshape(box,size(box,1),4,numparts);
        xy = permute(xy,[1 3 2]);
        xy = squeeze(xy); % x1 y1 x2 y2
        centbox = zeros(2,numparts);
        for bi = 1:numparts
            centbox(1,bi) = (xy(bi,3) + xy(bi,1)) / 2;
            centbox(2,bi) = (xy(bi,4) + xy(bi,2)) / 2;
        end
        centbox = centbox';
        b_pn(:,t_mi == 2,:) = centbox(t_mi == 2, :);
        
        g_part_scores(ii, part_bool) = t_ps;
        g_part_model_indicator(ii, part_bool) = m_ind;
        g_part_points(ii, part_bool, :) = b_pn;
    end
end


%% step 5: exhaustive search of model structure, TODO: chow-liu algorithm
% possible struct configurations
g_K = cell(1,4);
g_K{1} = ones(1, 4*2+1); 
g_K{2} = ones(1, 5*2+1);
g_K{3} = ones(1, 6*2+1);
g_K{4} = ones(1, 7*2+1);
g_pa = cell(1,4);
g_pa{1} = [0 1 2 3 4 1 6 7 8]; % pa_4
g_pa{2} = [0 1 2 3 4 5 1 7 8 9 10]; % pa_5
g_pa{3} = [0 1 2 3 4 5 6 1 8 9 10 11 12]; % pa_6
g_pa{4} = [0 1 2 3 4 5 6 7 1 9 10 11 12 13 14]; % pa_7

% totally 8 candidates
g_part_bool = zeros(8,15);
g_part_bool(1,:) = [1 0 0 1 0 1 1 1 0 0 1 0 1 1 1]; % pa_4_1, {N, C, P5, M1, M2}
g_part_bool(2,:) = [1 1 0 1 0 1 1 1 1 0 1 0 1 1 1]; % pa_5_1, {N, I1, C, P5, M1, M2}
g_part_bool(3,:) = [1 0 1 1 0 1 1 1 0 1 1 0 1 1 1]; % pa_5_2, {N, I2, C, P5, M1, M2}
g_part_bool(4,:) = [1 0 0 1 1 1 1 1 0 0 1 1 1 1 1]; % pa_5_3, {N, C, P4, P5, M1, M2}
g_part_bool(5,:) = [1 1 1 1 0 1 1 1 1 1 1 0 1 1 1]; % pa_6_1, {N, I1, I2, C, P5, M1, M2}
g_part_bool(6,:) = [1 1 0 1 1 1 1 1 1 0 1 1 1 1 1]; % pa_6_2, {N, I1, C, P4, P5, M1, M2}
g_part_bool(7,:) = [1 0 1 1 1 1 1 1 0 1 1 1 1 1 1]; % pa_6_3, {N, I2, C, P4, P5, M1, M2}
g_part_bool(8,:) = [1 1 1 1 1 1 1 1 1 1 1 1 1 1 1]; % pa_7_1, {N, I1, I2, C, P4, P5, M1, M2}
g_part_bool = logical(g_part_bool);

model_scores = zeros(1,8);

for si = 1:8
    numparts = sum(g_part_bool(si,:));
    nParts = (numparts - 1) / 2;
    l_K = g_K{nParts-3};
    l_pa = g_pa{nParts-3};
    l_points = g_part_points(:,g_part_bool(si,:),:);
    part_color = hsv(nParts+1);
    part_color = [part_color; part_color(2:end,:)];
    l_colorset = cell(1,numparts);
    for i = 1:numparts
        l_colorset{i} = part_color(i,:);
    end
    l_name = [target '_struct_' num2str(si)];
    
    model_scores(si) = train_model_from_prior(tdir, l_K, l_pa, l_name, l_colorset, l_points, ...
        0.8, 1);
    
    close all;
    
    % visualize detections and models
    
    % TODO: score the model by poisson prior of number or prior of struct
    
end

for si = 1:8
    numparts = sum(g_part_bool(si,:));
    model_scores(si) = model_scores(si) ./ numparts;
%     model_scores(si) = model_scores(si) .* poisspdf(numparts, 6.2857);
end
