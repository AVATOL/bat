function dpm_test(det_results, output_dir, part_list, taxon_list, taxa, meta, trains, tests, params)

fsp = filesep;
det_results = strrep(det_results, '\', fsp);
output_dir = strrep(output_dir, '\', fsp);

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
            [boxes, pscore] = test_taxon_dpm(params, model, im); % TODO: check boxes(end) = pscore
            pscores(n) = pscore(1);
            %figure(1000); showboxes(im,boxes(1,:),{'g'}); pause(0.5);
        end

        thresholds(p,t) = min(pscores);
    end
    %thresholds(p,1) = min(thresholds(p,:));
end

save([cachedir 'dpm_test_single_thresholds.mat']);
end % try-catch

%% testing
for n = 1:length(tests)
    im = imread(tests(n).im);
    tests(n).imsiz = size(im);
    
    for p = 1:num_parts
        cid  = arrayfun(@(x) strcmp(x.name, part_list{p}), meta.chars);
        
        bba = cell(1,num_taxa);
        psa = -inf.*ones(1,num_taxa);
        
        for t = 1:num_taxa
            cls = [name '_part_' part_list{p} '_taxon_' taxon_list{t}];
            fprintf('(part %d, taxon %d): DPM testing %s...\n', p, t, cls);

            tid  = arrayfun(@(x) strcmp(x.name, taxon_list{t}), taxa);
            if taxa(tid).part_mask(p) == 0
                continue
            end
        
            %model = pmodels{p,t};
            assert(exist([cachedir cls '.mat'], 'file') > 0);
            load([cachedir cls]);
            fprintf('%s loaded.\n', cls);
            
            [boxes, pscore] = test_taxon_dpm(params, model, im); 
            bba{t} = boxes(1,:);
            psa(t) = pscore(1); 

            %figure(1000); showboxes(im,boxes(1,:),{'g'}); pause(0.5);
        end
        
        [pscore, ti] = max(psa);
        boxes = bba{ti};
        presence = (pscore >= thresholds(p,ti));
        
        sid  = arrayfun(@(x) (x.presence == presence) & strcmp(x.cid, meta.chars(cid).id), meta.states);
        assert(sum(sid) == 1);
        
        write_det_res(det_results, boxes(1:4), meta.chars(cid), meta.states(sid), tests(n)); 
        write_output(output_dir, pscore, meta.chars(cid), meta.states(sid), tests(n));
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
%             [boxes, pscore] = test_taxon_dpm(params, model, im); 
%             boxes = boxes(1,:);
%             pscore = pscore(1);
%             presence = (pscore >= thresholds(p,t)); 
%             
%             
%             sid  = arrayfun(@(x) (x.presence == presence) & strcmp(x.cid, meta.chars(cid).id), meta.states);
%             assert(sum(sid) == 1);
%             
%             write_det_res(det_results, boxes(1:4), meta.chars(cid), meta.states(sid), subsamps(n)); 
%             write_output(output_dir, pscore, meta.chars(cid), meta.states(sid), subsamps(n)); 
% 
%             %figure(1000); showboxes(im,boxes(1,:),{'g'}); pause(0.5);
%         end
%     end
% end


%% helper functions
function write_det_res(det_results, bb, part, state, samp)

fsp = filesep;

x = (bb(1) + bb(3))/2;
y = (bb(2) + bb(4))/2;
h = samp.imsiz(1);
w = samp.imsiz(2);
x = x*100 / w;
y = y*100 / h;

file = [det_results fsp samp.id '_' part.id '.txt'];
fp = fopen(file, 'w');

content = [num2str(x) ',' num2str(y) ':' part.id ':' part.name ':' state.id ':' state.name '\n'];
fprintf(fp, content);

fclose(fp);

function write_output(output_dir, pscore, part, state, samp)

fsp = filesep;

[~,im,ext] = fileparts(samp.im);
im = ['media' fsp im ext];
sub_dir = strsplit(output_dir, 'output');
sub_dir = sub_dir{2};
det_file = ['detection_results' sub_dir fsp samp.id '_' part.id '.txt'];

file = [output_dir fsp 'sorted_output_data_' part.id '_' part.name '.txt'];
fp = fopen(file, 'a');

content = ['image_scored' '|' im '|' state.id '|' state.name '|' det_file '|' samp.tid '|1|' num2str(pscore) '\n'];
fprintf(fp, content);

fclose(fp);
