function avatol_test(det_results, output_dir, part_list, taxon_list, taxa, meta, trains, tests, params)
%

fsp = filesep;
det_results = strrep(det_results, '\', fsp);
output_dir = strrep(output_dir, '\', fsp);

% delete old files
delete([det_results fsp '*']);
delete([output_dir fsp '*']);

name = [part_list{:}];
cachedir = params.cachedir;

num_parts = length(part_list);
num_taxa = length(taxon_list);
platt_params = cell(1, num_taxa);

%% platt params
try 
    load([cachedir 'platt_params.mat']);
catch
for t = 1:num_taxa
    cls = [name '_DPM_taxon_' taxon_list{t}];
    fprintf('(taxon %d): estimating platt params %s...\n', t, taxon_list{t});

    if exist([cachedir cls '.mat'], 'file')
        load([cachedir cls]);
    end

    tid  = arrayfun(@(x) strcmp(x.name, taxon_list{t}), taxa);
    pmsk = taxa(tid).part_mask;
    
    % select samples for t
    tidx = arrayfun(@(x) strcmp(x.taxon, taxon_list{t}), trains); % in t
    subsamps = trains(tidx);
    
    if isempty(subsamps)
        continue
    end

    % keep only existing points/bboxes
    for n = 1:length(subsamps)
        subsamps(n).x1 = subsamps(n).x1(pmsk); 
        subsamps(n).y1 = subsamps(n).y1(pmsk);
        subsamps(n).x2 = subsamps(n).x2(pmsk);
        subsamps(n).y2 = subsamps(n).y2(pmsk);
        subsamps(n).point = subsamps(n).point(pmsk,:);
    end

    [pAs,pBs] = est_platt_params(model, subsamps, params);
    platt_params{t} = zeros(num_parts,2);
    platt_params{t}(pmsk,1) = pAs;
    platt_params{t}(pmsk,2) = pBs;

    clear subsamps;
end

save([cachedir 'platt_params.mat'], 'platt_params');
end

%% present teeth
for t = []%1:num_taxa
    cls = [name '_DPM_taxon_' taxon_list{t}];
    fprintf('(taxon %d): DPM testing %s...\n', t, cls);

    if exist([cachedir cls '.mat'], 'file')
        load([cachedir cls]);
        fprintf('%s loaded.\n', cls);
    end

    tid  = arrayfun(@(x) strcmp(x.name, taxon_list{t}), taxa);
    pmsk = taxa(tid).part_mask;
    
    % select samples for t
    tidx = arrayfun(@(x) strcmp(x.taxon, taxon_list{t}), tests); % in t
    subsamps = tests(tidx);
    
    if isempty(subsamps)
        continue
    end

    % keep only existing points/bboxes
    for n = 1:length(subsamps)
        subsamps(n).x1 = subsamps(n).x1(pmsk); 
        subsamps(n).y1 = subsamps(n).y1(pmsk);
        subsamps(n).x2 = subsamps(n).x2(pmsk);
        subsamps(n).y2 = subsamps(n).y2(pmsk);
        subsamps(n).point = subsamps(n).point(pmsk,:);
    end
    
    % set params 
    params.latent    = 0;

    % testing
    for i = 1:length(subsamps)
        im = imread(subsamps(i).im);
        pAs = platt_params{t}(pmsk,1);
        pBs = platt_params{t}(pmsk,2);

        tic
        [boxes,pscores] = test_single_dpm(params, model, im, pAs, pBs);
        fprintf('%s tested in %.2fs.\n', subsamps(i).id, toc);
        
        % write det_res and output
        subsamps(i).imsiz = size(im);
        bbs = boxes(1,1:end-2);
        bbs = reshape(bbs, [4,model.num_parts])';
        boxes = zeros(num_parts,4);
        boxes(pmsk,:) = bbs;
        pss = pscores(1,:);
        pscores = zeros(1,num_parts);
        pscores(pmsk) = pss;
        
        for p = find(pmsk == 1)
            presence = (pscores(p) >= 0.5);
            sid  = arrayfun(@(x) (x.presence == presence) & strcmp(x.cid, meta.chars(p).id), meta.states);
            assert(sum(sid) == 1);
            %avatol_write(det_results, output_dir, boxes(p,:), pscores(p), ...
            %    meta.chars(p), meta.states(sid), subsamps(i));
        end

        B = [subsamps(i).x1;subsamps(i).y1;subsamps(i).x2;subsamps(i).y2];
        B = reshape(B,[4*taxa(tid).num_parts,1])';

        %figure(1000); showboxesGT(im, boxes(1,:), B, taxa(tid).part_color); 
        %title(sprintf('%d ', pscores(1,:)));
        %pause;
        %export_fig([cls '_det_res.png']);
    end

    clear subsamps;
end % taxa

%% absent teeth
for n = 1:length(tests)
    fprintf('testing: %d, %s, %s\n', n, tests(n).id, tests(n).taxon);
    im = imread(tests(n).im);
    tests(n).imsiz = size(im);
    
    for p = find(tests(n).part_mask == 0)
        cid  = arrayfun(@(x) strcmp(x.name, part_list{p}), meta.chars);
        bba = cell(1,num_taxa);
        psa = -inf.*ones(1,num_taxa);
        
        for t = 1:num_taxa
            %fprintf('(%d, %d): %s, %s\n', p, t, part_list{p}, taxon_list{t});  

            %tid  = arrayfun(@(x) strcmp(x.name, taxon_list{t}), taxa);
            if taxa(t).part_mask(p) == 0 % no such part model indexed by (p,t)
                continue
            end
        
            cls = [name '_part_' part_list{p} '_taxon_' taxon_list{t}];
            assert(exist([cachedir cls '.mat'], 'file') > 0);
            load([cachedir cls]);
            
            pA = platt_params{t}(p,1);
            pB = platt_params{t}(p,2);
            params.latent = 0;
            
            [boxes, pscore] = test_single_dpm(params, model, im, pA, pB); 
            bba{t} = boxes(1,:);
            psa(t) = pscore(1); 

            %figure(1000); showboxes(im,boxes(1,:),{'g'}); 
            %title(sprintf('%s, %s: %s, %s', tests(n).id, tests(n).taxon, ...
            %    part_list{p}, taxon_list{t}));
        end
        
        %[pscore, ti] = max(psa);
        psa(psa == -inf) = max(psa); 
        [pscore, ti] = min(psa); % TODO: should hard_neg mine here
        boxes = bba{ti};
        presence = (pscore >= 0.5);
        
        fprintf('gt %d, presence %d, pscore %f\n', tests(n).part_mask(p), presence, pscore);
        
        sid  = arrayfun(@(x) (x.presence == presence) & strcmp(x.cid, meta.chars(cid).id), meta.states);
        assert(sum(sid) == 1);
        
        %avatol_write(det_results, output_dir, boxes(1:4), pscore, meta.chars(cid), meta.states(sid), tests(n));
        
        %figure(1001); showboxes(im,boxes(1,:),{'y'}); 
        %title(sprintf('%s, %s: %s, %s: gt %d, pred %d', tests(n).id, tests(n).taxon, ...
        %        part_list{p}, taxon_list{ti}, tests(n).part_mask(p), presence));
    end
end

