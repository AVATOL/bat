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

train_taxa_feat = [1 2 3 4 6 7 8 10 13 14 15 16 17 20 24];
train_taxa_ind = [1 2 3 4 6 7 10 13 14 17 20 24];
test_taxa_ind = sort(setdiff(1:num_taxa, train_taxa_ind));
train_taxa = taxon_list(train_taxa_ind);
test_taxa = taxon_list(test_taxa_ind);

load('bat_mat/psa_n.mat');
load('bat_mat/bba_n.mat');

for p = 1:num_parts
    tr_ind = arrayfun(@(x) ismember(x.taxon, train_taxa), samples);
    te_ind = arrayfun(@(x) ismember(x.taxon, test_taxa), samples);

    pi = arrayfun(@(x) x.part_mask(p) == 1, samples);
    ni = ~pi;
    
    tr_pos_ind = tr_ind & pi;
    tr_neg_ind = tr_ind & ni;
    te_pos_ind = te_ind & pi;
    te_neg_ind = te_ind & ni;
    
    fprintf('LR %d: train (%d,%d,%d), test (%d,%d,%d)\n', p, ...
        sum(tr_ind),sum(tr_pos_ind),sum(tr_neg_ind), ...
        sum(te_ind),sum(te_pos_ind),sum(te_neg_ind));
    
    X = psa_n{p};
    X = X(train_taxa_feat, :);
    X(X == -inf) = 0;
    
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
    
    bba = bba_n{p};
    bba = bba(train_taxa_feat, :, :);
    bba_tr = bba(:, :, tr_ind);
    bba_te = bba(:, :, te_ind);
    
    cid  = arrayfun(@(x) strcmp(x.name, part_list{p}), meta.chars);
    
    subsamps = samples(te_ind);
    for n = 1:sum(te_ind)
        fprintf('testing: %d, %s, %s\n', n, subsamps(n).id, subsamps(n).taxon);
        im = imread(subsamps(n).im);
        subsamps(n).imsiz = size(im);
        
        presence = clte(n) == 1;
        sid  = arrayfun(@(x) (x.presence == presence) & strcmp(x.cid, meta.chars(cid).id), meta.states);
        assert(sum(sid) == 1);
        
        bboxes = bba_te(:,:,n);
        [~, ti] = sort(bboxes(:,end), 'descend');
        bboxes = bboxes(ti,:);
        bb = bboxes(1,:);
        
        pscore = Zte(n,1);
        
        avatol_write(det_results, output_dir, bb(1:4), pscore, ...
            meta.chars(cid), meta.states(sid), subsamps(n));
        
%         figure(1001); showboxes(im, bboxes(1:5,:), {'y'}); % best
%         title(sprintf('(%s, %s, %s): use pmodel %s: gt %d, pred %d (%f)', ...
%             part_list{p}, subsamps(n).id, subsamps(n).taxon, ...
%             taxon_list{ti(1)}, ...
%             subsamps(n).part_mask(p), presence, pscore));
%         pause(1);
    end
    clear subsamps;

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
        
%         figure(1001); showboxes(im, bboxes(1:5,:), {'y'}); % best
%         title(sprintf('(%s, %s, %s): use pmodel %s: gt %d, pred %d (%f)', ...
%             part_list{p}, subsamps(n).id, subsamps(n).taxon, ...
%             taxon_list{ti(1)}, ...
%             subsamps(n).part_mask(p), presence, pscore));
%         pause(1);
    end
    clear subsamps;
end
