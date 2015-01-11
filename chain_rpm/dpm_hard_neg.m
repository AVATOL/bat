function label = dpm_hard_neg(params, model, xi, yi)
%

params.latent = 1;
[boxes,~,fmaps] = test_single_dpm(params, model, xi.pyra);

[~,ii] = max(boxes(:,end)); 
label.bbox = boxes(ii,:);
label.level = ii;
label.fmap = fmaps{ii};
