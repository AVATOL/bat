function [pAs,pBs] = est_platt_params(model, samples, params)
%

nvsp = 5; % 5 times more neg than pos
overlap = 0.3;
sizx = params.tsize(1); sizy = params.tsize(2);
nV = model.num_parts;
pos_scores = cell(nV,1);
neg_scores = cell(nV,1);
pAs = zeros(nV,1);
pBs = zeros(nV,1);

for n = 1:length(samples)
    im = imread(samples(n).im);
    pyra = hog_pyra(im, params);
    bbox = [samples(n).x1' samples(n).y1' samples(n).x2' samples(n).y2'];

    filters = cell(nV,1);
    for k = 1:nV
        filters{k} = model.node(k).w;
    end

    for lvl = 1:length(pyra.feat)
        resp = fconv(pyra.feat{lvl},filters,1,length(filters)); % return 1xnV 
    
        for k = 1:nV
            unary = resp{k} + model.bias(k).w;

            ovmask = testoverlap(sizx,sizy,pyra,lvl,bbox(k,:),overlap);
    
            tpos = unary(ovmask);
            pos_scores{k} = cat(1,pos_scores{k},tpos);
            
            tneg = unary(~ovmask);
            %tneg = sort(tneg,'descend');
            perm = randperm(length(tneg));
            tneg = tneg(perm(1:length(tpos)*nvsp)); % randomly select negs
            neg_scores{k} = cat(1,neg_scores{k},tneg);
        end % nV
    end
end

for k = 1:nV
    scores = [pos_scores{k}; neg_scores{k}]; 
    labels = [ones(length(pos_scores{k}),1); -1.*ones(length(neg_scores{k}),1)];
    [pAs(k),pBs(k)] = platt_scaling(scores, labels);
end
