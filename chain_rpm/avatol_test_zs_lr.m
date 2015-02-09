function avatol_test_zs_lr(det_results, output_dir, part_list, taxon_list, taxa, meta, trains, tests, params)

fsp = filesep;
det_results = strrep(det_results, '\', fsp);
output_dir = strrep(output_dir, '\', fsp);

% delete old files
delete([det_results fsp '*']);
delete([output_dir fsp '*']);

name = [part_list{:}];
cachedir = params.cachedir;

train_test = cat(2,trains,tests); % DEBUG
samples = train_test; % DEBUG

num_parts = length(part_list);
num_taxa = length(taxon_list);
num_samples = length(samples);

% specify train_taxa and test_taxa
train_taxa_ind = [1 2 3 4 6 7 10 13 14 17 20 24];
test_taxa_ind = sort(setdiff(1:num_taxa, train_taxa_ind));
train_taxa = taxon_list(train_taxa_ind);
test_taxa = taxon_list(test_taxa_ind);

train_taxa_feat = train_taxa_ind;
dim = length(train_taxa_feat); 

load('bat_mat/psa_n.mat'); % pscores
load('bat_mat/bba_n.mat'); % bboxes

for p = 1:num_parts
    tr_ind = arrayfun(@(x) ismember(x.taxon, train_taxa), samples);
    te_ind = arrayfun(@(x) ismember(x.taxon, test_taxa), samples);

    pi = arrayfun(@(x) x.part_mask(p) == 1, samples); % samples have p
    ni = ~pi;
    
    tr_pos_ind = tr_ind & pi; % training samples have p - pos
    tr_neg_ind = tr_ind & ni; % training samples without p - neg
    te_pos_ind = te_ind & pi; % testing samples have p - pos
    te_neg_ind = te_ind & ni; % testing samples without p - neg
    
    fprintf('LR %d: train (%d,%d,%d), test (%d,%d,%d)\n', p, ...
        sum(tr_ind),sum(tr_pos_ind),sum(tr_neg_ind), ...
        sum(te_ind),sum(te_pos_ind),sum(te_neg_ind));
    
    % prepare X and y for LR
    X = psa_n{p};
    X = X(train_taxa_feat, :);
    X(X == -inf) = 0;
    
    bba = bba_n{p};
    bba = bba(train_taxa_feat, :, :);
    
    [bb_1, bb_2] = meshgrid(1:dim, 1:dim);
    bb_1 = tril(bb_1, -1); 
    %bb_1 = bb_1([11 12], :); 
    bb_1 = bb_1(bb_1 > 0);
    bb_2 = tril(bb_2, -1); 
    %bb_2 = bb_2([11 12], :); 
    bb_2 = bb_2(bb_2 > 0);
    bba_1 = bba(bb_1,:,:);
    bba_2 = bba(bb_2,:,:);
    OV = zeros(length(bb_1),num_samples);
    
    for n = 1:num_samples % TODO: improve for loops here
        for j = 1:length(bb_1)
            OV(j,n) = bboverlap(bba_1(j,:,n), bba_2(j,:,n));
        end
    end
    
    X = [X; OV]; % X includes part scores and overlaps between each other
    
    % train-test split
    Xtr = X(:, tr_ind);
    ytr = zeros(1,num_samples);
    ytr(tr_pos_ind) = 1;
    ytr(tr_neg_ind) = 2;
    ytr(ytr == 0) = [];
    
    Xte = X(:, te_ind);
    yte = zeros(1,num_samples);
    yte(te_pos_ind) = 1;
    yte(te_neg_ind) = 2;
    yte(yte == 0) = [];
        
    % train LR
    if exist(['lr_presence_' num2str(p) '.mat'], 'file')
        load(['lr_presence_' num2str(p) '.mat']);
    else
        net = train_lr(Xtr', ytr');
        save(['lr_presence_' num2str(p) '.mat'], 'net');
    end
    
    % test LR
    [cltr, Ztr, pcorr_tr] = test_lr(net, Xtr', ytr');
    [clte, Zte, pcorr_te] = test_lr(net, Xte', yte');
    
    fprintf('results: train (%f,%f), test (%f,%f)\n', ...
        pcorr_tr(1), pcorr_tr(2), ...
        pcorr_te(1), pcorr_te(2));
    
    % attribute classification for each sample (testing on te and tr)
    cid  = arrayfun(@(x) strcmp(x.name, part_list{p}), meta.chars);
    
    bba_tr = bba(:, :, tr_ind);
    bba_te = bba(:, :, te_ind);
    
    % write results
    % te phase
    subsamps = samples(te_ind);
    acc_cnt = 0;
    for n = 1:sum(te_ind)
        fprintf('testing: %d, %s, %s\n', n, subsamps(n).id, subsamps(n).taxon);
        im = imread(subsamps(n).im);
        subsamps(n).imsiz = size(im);
        
        presence = clte(n) == 1;
        sid  = arrayfun(@(x) (x.presence == presence) & strcmp(x.cid, meta.chars(cid).id), meta.states);
        assert(sum(sid) == 1);
        
        if clte(n) == subsamps(n).part_mask(p)
            acc_cnt = acc_cnt + 1;
        end
        
        bboxes = bba_te(:,:,n);
        [~, ti] = sort(bboxes(:,end), 'descend');
        bboxes = bboxes(ti,:);
        bb = bboxes(1,:);
        
        pscore = Zte(n,1);
        
        avatol_write(det_results, output_dir, bb(1:4), pscore, ...
           meta.chars(cid), meta.states(sid), subsamps(n));
        
        if params.show_interm
            figure(1001); showboxes(im, bboxes(1:5,:), {'y'}); % best
            title(sprintf('(%s, %s, %s): use pmodel %s: gt %d, pred %d (%f)', ...
                part_list{p}, subsamps(n).id, subsamps(n).taxon, ...
                taxon_list{ti(1)}, ...
                subsamps(n).part_mask(p), presence, pscore));
            pause(1);
        end
    end
    clear subsamps;

    fprintf('accuracy of part %s is %f', part_list{p}, acc_cnt / sum(te_ind));
    
    % tr phase
    subsamps = samples(tr_ind);
    for n = 1:sum(tr_ind)
        fprintf('training: %d, %s, %s\n', n, subsamps(n).id, subsamps(n).taxon);
        im = imread(subsamps(n).im);
        subsamps(n).imsiz = size(im);
        
        presence = cltr(n) == 1;
        sid  = arrayfun(@(x) (x.presence == presence) & strcmp(x.cid, meta.chars(cid).id), meta.states);
        assert(sum(sid) == 1);
        
        bboxes = bba_tr(:,:,n);
        [~, ti] = sort(bboxes(:,end), 'descend');
        bboxes = bboxes(ti,:);
        bb = bboxes(1,:);
        
        pscore = Ztr(n,1);
        
        avatol_write(det_results, output_dir, bb(1:4), pscore, ...
           meta.chars(cid), meta.states(sid), subsamps(n), 2); % training_data
        
        if params.show_interm
            figure(1001); showboxes(im, bboxes(1:5,:), {'y'}); % best
            title(sprintf('(%s, %s, %s): use pmodel %s: gt %d, pred %d (%f)', ...
                part_list{p}, subsamps(n).id, subsamps(n).taxon, ...
                taxon_list{ti(1)}, ...
                subsamps(n).part_mask(p), presence, pscore));
            pause(1);
        end
    end
    clear subsamps;
end
