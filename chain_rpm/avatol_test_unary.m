function avatol_test_unary(det_results, output_dir, part_list, taxon_list, taxa, meta, trains, tests, params)
% TODO: check boxes(end) = pscore

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
thresholds = inf.*ones(num_parts, num_taxa);
pmodels = cell(num_parts, num_taxa);

%% trains -> thresholds
try 
    load([cachedir 'dpm_test_single_thresholds.mat']);
catch   
    for p = 1:num_parts
        for t = 1:num_taxa
            cls = [name '_part_' part_list{p} '_taxon_' taxon_list{t}];
            fprintf('(part %d, taxon %d): DPM testing %s...\n', p, t, cls);

            % select samples for p and t
            tidx = arrayfun(@(x) strcmp(x.taxon, taxon_list{t}), trains); % in t
            tid  = arrayfun(@(x) strcmp(x.name, taxon_list{t}), taxa);
            pidx = arrayfun(@(x) taxa(tid).part_mask(p) == 1, trains); % has p
            clear subsamps;
            subsamps = trains(tidx & pidx);

            if isempty(subsamps)
                continue
            end

            assert(exist([cachedir cls '.mat'], 'file') > 0);
            load([cachedir cls]);
            pmodels{p,t} = model;
            fprintf('%s loaded.\n', cls);

            pscores = zeros(length(subsamps),1);
            for n = 1:length(subsamps)
                im = imread(subsamps(n).im);
                [boxes, pscore] = test_single_dpm(params, model, im); 
                pscores(n) = pscore(1);
                %figure(1000); showboxes(im,boxes(1,:),{'g'}); pause(0.5);
            end

            thresholds(p,t) = min(pscores);
        end
    end

    save([cachedir 'dpm_test_single_thresholds.mat']);
end % try-catch

%% testing
for n = 1:length(tests)
    fprintf('testing: %d, %s, %s\n', n, tests(n).id, tests(n).taxon);
    im = imread(tests(n).im);
    tests(n).imsiz = size(im);
    
    for p = 1:num_parts
        cid  = arrayfun(@(x) strcmp(x.name, part_list{p}), meta.chars);
        bba = cell(1,num_taxa);
        psa = -inf.*ones(1,num_taxa);
        
        for t = 1:num_taxa
            fprintf('(%d, %d): %s, %s\n', p, t, part_list{p}, taxon_list{t});  

            tid  = arrayfun(@(x) strcmp(x.name, taxon_list{t}), taxa);
            if taxa(tid).part_mask(p) == 0 % no such part model indexed by (p,t)
                continue
            end
        
            %model = pmodels{p,t};
            cls = [name '_part_' part_list{p} '_taxon_' taxon_list{t}];
            assert(exist([cachedir cls '.mat'], 'file') > 0);
            load([cachedir cls]);
            
            [boxes, pscore] = test_single_dpm(params, model, im); 
            bba{t} = boxes(1,:);
            psa(t) = pscore(1); 

            figure(1000); showboxes(im,boxes(1,:),{'g'}); 
            title(sprintf('%s, %s: %s, %s', tests(n).id, tests(n).taxon, ...
                part_list{p}, taxon_list{t}));
        end
        
        [pscore, ti] = max(psa);
        boxes = bba{ti};
        presence = (pscore >= thresholds(p,ti));
        
        sid  = arrayfun(@(x) (x.presence == presence) & strcmp(x.cid, meta.chars(cid).id), meta.states);
        assert(sum(sid) == 1);
        
        avatol_write(det_results, output_dir, boxes(1:4), pscore, meta.chars(cid), meta.states(sid), tests(n));
        
        figure(1001); showboxes(im,boxes(1,:),{'y'}); 
        title(sprintf('%s, %s: %s, %s: gt %d, pred %d', tests(n).id, tests(n).taxon, ...
                part_list{p}, taxon_list{ti}, tests(n).part_mask(p), presence));
    end
end

% for p = 1:num_parts
%     cid  = arrayfun(@(x) strcmp(x.name, part_list{p}), meta.chars);
%     for t = 1:num_taxa
%         cls = [name '_part_' part_list{p} '_taxon_' taxon_list{t}];
%         fprintf('(part %d, taxon %d): DPM testing %s...\n', p, t, cls);
% 
%         % select samples for p and t
%         tidx = arrayfun(@(x) strcmp(x.taxon, taxon_list{t}), tests); % in t
%         tid  = arrayfun(@(x) strcmp(x.name, taxon_list{t}), taxa);
%         pidx = arrayfun(@(x) taxa(tid).part_mask(p) == 1, tests); % has p
%         subsamps = tests(tidx & pidx);
% 
%         if isempty(subsamps)
%             continue
%         end
%         
%         assert(exist([cachedir cls '.mat'], 'file') > 0);
%         load([cachedir cls]);
%         fprintf('%s loaded.\n', cls);
% 
%         for n = 1:length(subsamps)
%             im = imread(subsamps(n).im);
%             subsamps(n).imsiz = size(im);
%             [boxes, pscore] = test_single_dpm(params, model, im); 
%             boxes = boxes(1,:);
%             pscore = pscore(1);
%             presence = (pscore >= thresholds(p,t)); 
%             
%             
%             sid  = arrayfun(@(x) (x.presence == presence) & strcmp(x.cid, meta.chars(cid).id), meta.states);
%             assert(sum(sid) == 1);
%             
%             avatol_write(det_results, output_dir, boxes(1:4), pscore, meta.chars(cid), meta.states(sid), tests(n));
% 
%             %figure(1000); showboxes(im,boxes(1,:),{'g'}); pause(0.5);
%         end
%     end
% end


