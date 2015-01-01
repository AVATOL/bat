function loss = chainrpm_loss(params, ytruth, ypred)
% for each box, 1) if intersect(box,gt)/union(box,gt) < overlap,
% then loss += 1/num_parts*(1-weight)
% 2) if presence is incorrect, then loss += 1/num_parts*weight
%
% NOTE: for individual part training, y.type(other_parts) = 0
% NOTE: for individual taxon training, presence_w = 0

num_parts = params.num_parts; % num_parts = 1 when singe part
overlap = params.overlap;
pw = params.presence_w;

xy = reshape(ypred.bbox(1:end-2),[4,num_parts]);
%xygt = reshape(ytruth.bbox(1:end-2),[4,num_parts]);
xygt = ytruth.bbox';

loss = 0;
for k = 1:num_parts
    % at least one == 0
    if ytruth.type(k) * ypred.type(k) == 0 
        % another ~= 0, add loc loss anyway
        if ytruth.type(k) ~= ypred.type(k)
            loss = loss + (1/num_parts)*pw; % presence loss
            loss = loss + (1/num_parts)*(1-pw); % location loss
            continue
        else
            % otherwise no presence loss
            % indiv part training goes this when non-target part
        end
    end

    % none == 0, then calc location loss
    x1 = xy(1,k);
    y1 = xy(2,k);
    x2 = xy(3,k);
    y2 = xy(4,k);
    
    bx1 = xygt(1,k);
    by1 = xygt(2,k);
    bx2 = xygt(3,k);
    by2 = xygt(4,k);
    
    % Compute intersection with bbox
    xx1 = max(x1,bx1);
    xx2 = min(x2,bx2);
    yy1 = max(y1,by1);
    yy2 = min(y2,by2);
    w = xx2 - xx1 + 1;
    h = yy2 - yy1 + 1;
    w(w<0) = 0;
    h(h<0) = 0;
    inter  = h'*w;
    
    % area of (possibly clipped) detection windows and original bbox
    area = (y2-y1+1)'*(x2-x1+1);
    box = (by2-by1+1)*(bx2-bx1+1);

    % thresholded overlap
    if inter / (area + box - inter) < overlap
        loss = loss + (1/num_parts)*(1-pw); % location loss
    end
end
