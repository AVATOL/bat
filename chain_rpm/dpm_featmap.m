function phi = dpm_featmap(params, model, x, y)
% computes the joint feature map phi(x,y). 
% It is important that the implementation is consistent with the detect_oracle.m!
% 
% INPUT:
% params = {parts, warp, len, sbin}
% x = {feat, pyra}
% y = {bbox, level}
%
% OUTPUT:
% phi = {bias_1, HOG_1, bias_2, HOG_2, ..., bias_P, HOG_P, def_2, ..., def_P}
% 
% TODO: y.level isn't in GT, use same level as y_star?
% TODO: (py,px) from center not left-upper corner of bbox
% TODO: use warp to get rid of y.level

num_parts = params.num_parts; % num_parts = 1 when single part
len = params.len;
sizy = params.tsize(1);
sizx = params.tsize(2);
%wdim = prod(params.tsize);

phi = zeros(len,1);

%% case 1: use y.fmap from dpm_oracle
if isfield(y, 'fmap')
    for b = y.fmap.blocks
        n  = numel(b.x);
        i1 = b.i;
        i2 = i1 + n - 1;
        is = i1:i2; 
        f  = reshape(b.x,n,1);
        phi(is) = f;
    end
    return
end

%% case 2: individual part warped
if params.warp
    phi(1) = 1;
    phi(2:end) = x.feat;
    return
end

%% case 3: compute feature from scratch
bb = y.bbox';
%level = y.level;
level = 1; % since not in GT 
layer = x.pyra.feat{level};
pady  = x.pyra.pady;
padx  = x.pyra.padx;
scale = x.pyra.scale(level); 

for k = 1:num_parts
    % bias
    pt = model.bias(k).i;
    phi(pt) = 1; 
    
    % hog
    pt = model.node(k).i;
    px = ceil((bb(1,k)-1) / scale + padx + 1); % TODO: use testoverlap() better?
    py = ceil((bb(2,k)-1) / scale + pady + 1);
    f = layer(py:py+sizy-1, px:px+sizx-1, :);
    assert(length(model.node(k).w(:)) == length(f(:)));
    wdim = length(f(:));
    phi(pt:pt+wdim-1) = f; 

    % def
    par = model.parent(k);
    if par
        pt = model.edge(k,par).i;
        ppx = ceil((bb(1,par)-1) / scale + padx + 1); % TODO: check use ceil or round, round seems incorrect
        ppy = ceil((bb(2,par)-1) / scale + pady + 1);
        fd = def_feat(ppx,ppy,px,py,pady,padx,model.edge(k,par)); 
        phi(pt:pt+4-1) = fd; 
    end
end
