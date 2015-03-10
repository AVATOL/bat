function dpm_test(part_list, taxon_list, taxa, samples, params)

name = [part_list{:}];
cachedir = params.cachedir;
file = [cachedir name '.log'];
delete(file);
diary(file);

num_parts = length(part_list);
num_taxa = length(taxon_list);
num_samples = length(samples);
params.num_parts = num_parts;
params.num_taxa = num_taxa;
params.num_samples = num_samples;
params.latent = 1;

fprintf('--------------------------------------\n');
fprintf('*=3=* test DPMs for each taxon\n');
all_bbovlp = cell(1,num_taxa);
for t = 1:num_taxa
    cls = [name '_DPM_taxon_' taxon_list{t}];
    fprintf('(taxon %d): DPM testing %s...\n', t, cls);
    
    assert(exist([cachedir cls '.mat'], 'file') > 0);
    load([cachedir cls]);
    fprintf('%s loaded.\n', cls);
    
    tid  = arrayfun(@(x) strcmp(x.name, taxon_list{t}), taxa);
    pmsk = taxa(tid).part_mask;
    
    % select samples for t
    tidx = arrayfun(@(x) strcmp(x.taxon, taxon_list{t}), samples); % in t
    subsamps = samples(tidx);
    
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

    if params.show_data
        vis_model(model);
    end

    all_bbovlp{t} = zeros(1,length(subsamps));
    for n = 1:length(subsamps)
        im = imread(subsamps(n).im);
        [boxes] = test_single_dpm(params, model, im);
        bb = boxes(1,:);
        
        if params.show_data
            figure(1000); showboxes(im,bb,taxa(tid).part_color);
            %pause;
        end
        
        bovlp = 0;
        num_parts = sum(taxa(tid).part_mask);
        bb_gt = [subsamps(n).x1;subsamps(n).y1;subsamps(n).x2;subsamps(n).y2]';
        bb = reshape(bb(1:end-2), [4, num_parts])';
        for k = 1:num_parts
            bovlp = bovlp + bboverlap(bb_gt(k,:), bb(k,:));
        end
        bovlp = bovlp / num_parts;
        all_bbovlp{t}(n) = bovlp;
        
        fprintf('(taxon %d, %s): bb_overlap = %f\n', t, cls, bovlp);
    end
    fprintf('*** (taxon %d, %s): ave_bb_overlap = %f\n', t, cls, mean(all_bbovlp{t}));
end

save('./cache/dpm_test_all_bbovlp.mat', 'all_bbovlp');
